"""The one Claude client of the pipeline: the Anthropic API, or an Anthropic-compatible gateway.

Gateway mode is on when CLAUDE_BASE_URL is set in pipeline/.env (with CLAUDE_AUTH_TOKEN, sent as a Bearer token),
the same keys the backend reads (doc-11). A gateway may not support structured outputs, so in gateway mode the JSON
Schema goes at the end of the system prompt and the answer is parsed from the text, with one more try on bad JSON,
like ClaudeService.askForJson in the backend. Without CLAUDE_BASE_URL nothing changes: the Anthropic API with
ANTHROPIC_API_KEY and structured outputs.
"""

import json
import os
from dataclasses import dataclass
from functools import cache
from typing import TypeVar

import anthropic
from pydantic import BaseModel

# The model a gateway gets when no model env is set: the STEYG one the server uses for words and sentences.
GATEWAY_DEFAULT_MODEL = "deepseek-v4.1-flash"

# US dollars per million tokens (input, output), for prompts up to 100K tokens. Same numbers as
# backend/src/main/resources/application.properties (app.claude.pricing.*). Haiku 5.5 checked 2026-10-15,
# Sonnet 5.5 2026-10-16, DeepSeek V4.1 Flash on STEYG 2026-10-20 (https://steyg.one).
PRICES = {
    "claude-haiku-5-5": (0.10, 0.50),
    "claude-sonnet-5-5": (2.00, 10.00),
    "deepseek-v4.1-flash": (0.30, 1.20),
}

# The same words the backend adds in gateway mode (ClaudeService.jsonInstruction).
JSON_INSTRUCTION = ("\nAnswer with ONLY one JSON object that follows this JSON Schema, with the fields in this order. "
                    "No Markdown, no code fence, no text before or after the object.\n")

T = TypeVar("T", bound=BaseModel)


def gateway() -> bool:
    return bool(os.environ.get("CLAUDE_BASE_URL"))


@cache
def client() -> anthropic.Anthropic:
    # Created once and reused. max_retries: the SDK waits and retries on 429, 5xx and connection errors.
    if gateway():
        # The URL without /v1, like the backend; the gateway takes a Bearer token, not x-api-key.
        return anthropic.Anthropic(base_url=os.environ["CLAUDE_BASE_URL"],
                                   auth_token=os.environ.get("CLAUDE_AUTH_TOKEN"), api_key=None, max_retries=5)
    return anthropic.Anthropic(max_retries=5)


def model(anthropic_model: str, step_env: str | None = None) -> str:
    """The model for one step: its own env (for example CLAUDE_JUDGE_MODEL) wins. In gateway mode CLAUDE_MODEL comes
    next, then deepseek-v4.1-flash; without a gateway the step keeps its Claude model."""
    if step_env and os.environ.get(step_env):
        return os.environ[step_env]
    if gateway():
        return os.environ.get("CLAUDE_MODEL") or GATEWAY_DEFAULT_MODEL
    return anthropic_model


def cost_usd(model_id: str, input_tokens: int, output_tokens: int) -> float:
    """Dollars for one call. A model without a price here is counted at the highest price listed."""
    price_in, price_out = PRICES.get(model_id) or (max(p[0] for p in PRICES.values()),
                                                  max(p[1] for p in PRICES.values()))
    return (input_tokens * price_in + output_tokens * price_out) / 1_000_000


@dataclass
class Parsed[T]:
    """A structured answer and the tokens it cost (both tries in gateway mode)."""

    output: T
    input_tokens: int
    output_tokens: int


def json_instruction(output_format: type[BaseModel]) -> str:
    return JSON_INSTRUCTION + json.dumps(output_format.model_json_schema(), ensure_ascii=False) + "\n"


def extract_json(text: str) -> str:
    """From the first { to the last }, so a code fence or a sentence around the object does not matter."""
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end < start:
        raise ValueError(f"no JSON object in the answer: {text[:120]!r}")
    return text[start:end + 1]


def text_of(response) -> str:
    # Only the text blocks: a model may send a thinking block first.
    return "".join(block.text for block in response.content if block.type == "text")


def parse(*, model: str, max_tokens: int, system: str, content: str, output_format: type[T]) -> Parsed[T]:
    """One structured call. Raises RuntimeError when the model refuses, the reply is cut off, or (gateway) the
    answer is still not valid JSON after a second try."""
    messages = [{"role": "user", "content": content}]
    if not gateway():
        response = client().messages.parse(model=model, max_tokens=max_tokens, system=system, messages=messages,
                                           output_format=output_format, output_config={"effort": "low"})
        if response.stop_reason == "refusal":
            raise RuntimeError(f"Claude refused: {response.stop_details}")
        if response.parsed_output is None:
            raise RuntimeError(f"No answer returned (stop_reason={response.stop_reason})")
        return Parsed(response.parsed_output, response.usage.input_tokens, response.usage.output_tokens)

    system = system + json_instruction(output_format)
    input_tokens = output_tokens = 0
    problem = ""
    for _ in range(2):  # one more try on bad JSON, like the backend
        response = client().messages.create(model=model, max_tokens=max_tokens, system=system, messages=messages)
        input_tokens += response.usage.input_tokens
        output_tokens += response.usage.output_tokens
        if response.stop_reason == "refusal":
            raise RuntimeError(f"The model refused: {getattr(response, 'stop_details', None)}")
        try:
            # Unknown fields are ignored and a missing required one fails, as in the backend.
            return Parsed(output_format.model_validate_json(extract_json(text_of(response))), input_tokens, output_tokens)
        except ValueError as error:  # pydantic's ValidationError is a ValueError
            problem = f"{error} (stop_reason={response.stop_reason})"
    raise RuntimeError(f"No valid JSON after 2 tries: {problem[:300]}")


def create(*, model: str, max_tokens: int, system: str | None, content, effort: str | None = None):
    """One plain call (the answer is read by the caller). effort is sent to the Anthropic API only: a gateway
    may not know output_config."""
    kwargs: dict = {"system": system} if system else {}
    if effort and not gateway():
        kwargs["output_config"] = {"effort": effort}
    return client().messages.create(model=model, max_tokens=max_tokens,
                                    messages=[{"role": "user", "content": content}], **kwargs)
