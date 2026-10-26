from types import SimpleNamespace
from typing import Any

import pytest

from app.config import Settings
from app.llm import LLM, BudgetExceeded, LLMRefused, LLMTruncated, cost_usd
from app.summarize import SUMMARY_PROMPT, Summary, summarize


class FakeMessages:
    """Stands in for client.beta.messages: records calls, returns a canned response."""

    def __init__(self, response: Any) -> None:
        self.response = response
        self.calls: list[dict[str, Any]] = []

    def parse(self, **kwargs: Any) -> Any:
        self.calls.append(kwargs)
        return self.response


def fake_client(stop_reason: str = "end_turn", parsed: Any = None) -> Any:
    usage = SimpleNamespace(
        input_tokens=1_000,
        output_tokens=200,
        cache_read_input_tokens=0,
        cache_creation_input_tokens=0,
    )
    response = SimpleNamespace(
        model="claude-opus-5-5",
        stop_reason=stop_reason,
        stop_details=None,
        usage=usage,
        parsed_output=parsed,
    )
    return SimpleNamespace(beta=SimpleNamespace(messages=FakeMessages(response)))


def settings(**overrides: Any) -> Settings:
    return Settings(_env_file=None, llm_model="claude-opus-5-5", **overrides)  # pyright: ignore[reportCallIssue]


def test_summarize_returns_parsed_output_and_sends_cached_versioned_prompt() -> None:
    expected = Summary(summary="A short text.", key_words=["text"])
    client = fake_client(parsed=expected)

    result = summarize(LLM(client, settings()), "Some text")

    assert result == expected
    call = client.beta.messages.calls[0]
    assert call["output_format"] is Summary
    assert call["system"][0]["text"] == SUMMARY_PROMPT.system
    assert call["system"][0]["cache_control"] == {"type": "ephemeral"}
    assert "Some text" in call["messages"][0]["content"]


def test_cost_counts_input_output_and_cache() -> None:
    usage = SimpleNamespace(
        input_tokens=1_000_000,
        output_tokens=100_000,
        cache_read_input_tokens=1_000_000,
        cache_creation_input_tokens=0,
    )
    # 1M in * $4 + 0.1M out * $20 + 1M cache read * $4 * 0.1
    assert cost_usd("claude-opus-5-5", usage) == pytest.approx(4.0 + 2.0 + 0.4)


def test_budget_stops_calls_once_spent() -> None:
    llm = LLM(
        fake_client(parsed=Summary(summary="s", key_words=[])), settings(llm_budget_usd=0.001)
    )

    summarize(llm, "first call is allowed")  # costs about $0.008
    with pytest.raises(BudgetExceeded):
        summarize(llm, "second call is blocked")


def test_refusal_and_truncation_are_errors() -> None:
    with pytest.raises(LLMRefused):
        summarize(LLM(fake_client(stop_reason="refusal"), settings()), "x")
    with pytest.raises(LLMTruncated):
        summarize(LLM(fake_client(stop_reason="max_tokens"), settings()), "x")
