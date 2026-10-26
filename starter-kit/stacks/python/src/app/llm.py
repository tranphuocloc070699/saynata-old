"""The one door to the LLM. Every model call in the app goes through `LLM.ask`.

What it adds on top of the SDK:
- timeouts and retries (the SDK retries 408/409/429/5xx and connection errors with backoff),
- a cost budget per run, checked before each call,
- the prompt name + version on every log line, so a change in output can be traced to a prompt change,
- structured output parsed into a pydantic model (no hand-written JSON parsing),
- prompt caching on the (stable) system prompt,
- clear errors for refusals and truncated output.
Tests pass a fake client; they never call the real API.
"""

import time
from dataclasses import dataclass
from typing import Any

import anthropic
import structlog
from pydantic import BaseModel

from app.config import Settings

log = structlog.get_logger()

# US dollars per million tokens: (input, output). Check https://claude.com/pricing when you change models.
PRICES: dict[str, tuple[float, float]] = {
    "claude-opus-5-5": (4.00, 20.00),
    "claude-sonnet-5-5": (2.00, 10.00),
    "claude-haiku-5-5": (0.10, 0.50),
}
# Cache reads cost about 10% of input, cache writes about 125%.
CACHE_READ_FACTOR = 0.1
CACHE_WRITE_FACTOR = 1.25


class LLMError(Exception):
    """Base class: callers can catch every LLM problem with one except."""


class BudgetExceeded(LLMError):
    pass


class LLMRefused(LLMError):
    pass


class LLMTruncated(LLMError):
    pass


@dataclass(frozen=True)
class Prompt:
    """A prompt has a name and a version. Bump the version whenever the text changes."""

    name: str
    version: int
    system: str


def make_client(settings: Settings) -> anthropic.Anthropic:
    key = settings.anthropic_api_key.get_secret_value() if settings.anthropic_api_key else None
    return anthropic.Anthropic(
        api_key=key, timeout=settings.llm_timeout_seconds, max_retries=settings.llm_max_retries
    )


def cost_usd(model: str, usage: Any) -> float:
    price_in, price_out = PRICES.get(model, (0.0, 0.0))
    cache_read = getattr(usage, "cache_read_input_tokens", 0) or 0
    cache_write = getattr(usage, "cache_creation_input_tokens", 0) or 0
    tokens_in = (
        usage.input_tokens + cache_read * CACHE_READ_FACTOR + cache_write * CACHE_WRITE_FACTOR
    )
    return (tokens_in * price_in + usage.output_tokens * price_out) / 1_000_000


class LLM:
    def __init__(self, client: anthropic.Anthropic, settings: Settings) -> None:
        self._client = client
        self._model = settings.llm_model
        self._budget_usd = settings.llm_budget_usd
        self.spent_usd = 0.0

    def ask[T: BaseModel](
        self, prompt: Prompt, user: str, output: type[T], max_tokens: int = 16_000
    ) -> T:
        if self.spent_usd >= self._budget_usd:
            raise BudgetExceeded(
                f"Spent ${self.spent_usd:.4f} of ${self._budget_usd:.2f} budget; not calling"
                f" {prompt.name}"
            )

        started = time.monotonic()
        response = self._client.beta.messages.parse(
            model=self._model,
            max_tokens=max_tokens,
            # Stable text first and cached; the changing part (user) comes after it.
            system=[
                {"type": "text", "text": prompt.system, "cache_control": {"type": "ephemeral"}}
            ],
            messages=[{"role": "user", "content": user}],
            output_format=output,
            # If the model declines for a safety reason, the API retries on a fallback model.
            betas=["server-side-fallback-2026-07-01"],
            fallbacks="default",
        )

        cost = cost_usd(self._model, response.usage)
        self.spent_usd += cost
        log.info(
            "llm_call",
            prompt=prompt.name,
            prompt_version=prompt.version,
            model=response.model,
            stop_reason=response.stop_reason,
            input_tokens=response.usage.input_tokens,
            output_tokens=response.usage.output_tokens,
            cache_read_tokens=getattr(response.usage, "cache_read_input_tokens", 0),
            cost_usd=round(cost, 6),
            spent_usd=round(self.spent_usd, 6),
            duration_ms=int((time.monotonic() - started) * 1000),
            request_id=getattr(response, "_request_id", None),
        )

        if response.stop_reason == "refusal":
            raise LLMRefused(f"{prompt.name}: model declined ({response.stop_details})")
        if response.stop_reason == "max_tokens":
            raise LLMTruncated(f"{prompt.name}: output hit max_tokens={max_tokens}")
        parsed = response.parsed_output
        if parsed is None:
            raise LLMError(f"{prompt.name}: no structured output in the response")
        return parsed
