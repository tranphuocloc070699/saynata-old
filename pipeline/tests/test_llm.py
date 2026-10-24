"""The shared Claude client: Anthropic mode and gateway mode, with a fake HTTP server (no real call)."""

import json
from types import SimpleNamespace

import anthropic
import httpx2 as httpx
import pytest
from pydantic import BaseModel

from pipeline import cli, collection, llm


class Answer(BaseModel):
    meaning: str
    level: str


def reply(text: str, input_tokens=10, output_tokens=5, stop_reason="end_turn") -> dict:
    return {"id": "msg_1", "type": "message", "role": "assistant", "model": "deepseek-v4.1-flash",
            "content": [{"type": "text", "text": text}], "stop_reason": stop_reason, "stop_sequence": None,
            "usage": {"input_tokens": input_tokens, "output_tokens": output_tokens}}


@pytest.fixture
def gateway(monkeypatch):
    """Gateway mode with a fake server. Give it the answers in order; it keeps every request it gets."""
    monkeypatch.setenv("CLAUDE_BASE_URL", "https://gateway.test")
    monkeypatch.setenv("CLAUDE_AUTH_TOKEN", "test-token")
    requests: list[httpx.Request] = []
    answers: list[dict] = []

    def handle(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        return httpx.Response(200, json=answers.pop(0))

    def fake_client():
        return anthropic.Anthropic(base_url="https://gateway.test", auth_token="test-token", api_key=None,
                                   max_retries=0, http_client=httpx.Client(transport=httpx.MockTransport(handle)))

    monkeypatch.setattr(llm, "client", fake_client)
    return SimpleNamespace(requests=requests, answers=answers)


def body(request: httpx.Request) -> dict:
    return json.loads(request.content)


def test_the_real_gateway_client_sends_a_bearer_token_to_the_base_url(monkeypatch):
    monkeypatch.setenv("CLAUDE_BASE_URL", "https://gateway.test")
    monkeypatch.setenv("CLAUDE_AUTH_TOKEN", "test-token")
    monkeypatch.setenv("ANTHROPIC_API_KEY", "should-not-be-sent")
    made = llm.client()
    assert str(made.base_url).rstrip("/") == "https://gateway.test"
    assert made.auth_token == "test-token" and made.api_key is None


def test_gateway_puts_the_schema_in_the_system_prompt_and_reads_json_in_a_code_fence(gateway):
    gateway.answers.append(reply('```json\n{"meaning": "to stop trying", "level": "B1", "extra": 1}\n```'))
    parsed = llm.parse(model="deepseek-v4.1-flash", max_tokens=500, system="Explain.", content="give up",
                       output_format=Answer)
    assert parsed.output == Answer(meaning="to stop trying", level="B1")
    assert (parsed.input_tokens, parsed.output_tokens) == (10, 5)
    request = gateway.requests[0]
    assert request.url.path == "/v1/messages"
    assert request.headers["authorization"] == "Bearer test-token"
    sent = body(request)
    assert sent["system"].startswith("Explain.\nAnswer with ONLY one JSON object")
    assert '"meaning"' in sent["system"]
    assert "output_config" not in sent and "output_format" not in sent


def test_gateway_tries_again_on_bad_json_and_counts_both_calls(gateway):
    gateway.answers += [reply("Sorry, I cannot format that.", 10, 5), reply('{"meaning": "m", "level": "A2"}', 12, 6)]
    parsed = llm.parse(model="m", max_tokens=100, system="s", content="c", output_format=Answer)
    assert parsed.output.level == "A2"
    assert (parsed.input_tokens, parsed.output_tokens) == (22, 11)
    assert len(gateway.requests) == 2


def test_gateway_gives_up_after_two_bad_answers(gateway):
    gateway.answers += [reply('{"meaning": "no level"}'), reply("still no json")]
    with pytest.raises(RuntimeError, match="No valid JSON after 2 tries"):
        llm.parse(model="m", max_tokens=100, system="s", content="c", output_format=Answer)
    assert len(gateway.requests) == 2


def test_gateway_refusal_is_an_error_without_a_second_try(gateway):
    gateway.answers.append(reply("", stop_reason="refusal"))
    with pytest.raises(RuntimeError, match="refused"):
        llm.parse(model="m", max_tokens=100, system="s", content="c", output_format=Answer)
    assert len(gateway.requests) == 1


def test_gateway_create_sends_no_effort(gateway):
    gateway.answers.append(reply("{}"))
    llm.create(model="m", max_tokens=100, system=None, content="c", effort="high")
    sent = body(gateway.requests[0])
    assert "output_config" not in sent and "system" not in sent


def test_anthropic_mode_keeps_structured_outputs_and_effort(monkeypatch):
    calls = {}

    class Messages:
        def parse(self, **kwargs):
            calls["parse"] = kwargs
            return SimpleNamespace(stop_reason="end_turn", parsed_output=Answer(meaning="m", level="B2"),
                                   usage=SimpleNamespace(input_tokens=3, output_tokens=4))

        def create(self, **kwargs):
            calls["create"] = kwargs

    monkeypatch.setattr(llm, "client", lambda: SimpleNamespace(messages=Messages()))
    parsed = llm.parse(model="claude-haiku-5-5", max_tokens=100, system="s", content="c", output_format=Answer)
    assert parsed.output.level == "B2"
    assert calls["parse"]["output_format"] is Answer and calls["parse"]["output_config"] == {"effort": "low"}
    assert calls["parse"]["system"] == "s"  # no schema added
    llm.create(model="claude-haiku-5-5", max_tokens=100, system="s", content="c", effort="high")
    assert calls["create"]["output_config"] == {"effort": "high"}


def test_model_resolution(monkeypatch):
    assert llm.model("claude-sonnet-5-5", "CLAUDE_SCENE_MODEL") == "claude-sonnet-5-5"  # no gateway
    monkeypatch.setenv("CLAUDE_SCENE_MODEL", "my-scene-model")
    assert llm.model("claude-sonnet-5-5", "CLAUDE_SCENE_MODEL") == "my-scene-model"  # a step env wins everywhere
    monkeypatch.setenv("CLAUDE_BASE_URL", "https://gateway.test")
    assert llm.model("claude-haiku-5-5") == "deepseek-v4.1-flash"
    monkeypatch.setenv("CLAUDE_MODEL", "other-model")
    assert llm.model("claude-haiku-5-5") == "other-model"
    assert llm.model("claude-sonnet-5-5", "CLAUDE_SCENE_MODEL") == "my-scene-model"


def test_prices():
    assert llm.cost_usd("deepseek-v4.1-flash", 1_000_000, 1_000_000) == pytest.approx(1.50)
    assert llm.cost_usd("unknown", 1_000_000, 1_000_000) == pytest.approx(12.00)  # the highest listed


def test_collection_cost_per_item_follows_the_gateway_model(monkeypatch):
    assert collection.claude_model() == collection.CLAUDE_MODEL
    assert collection.cost_per_item() == pytest.approx(collection.CLAUDE_COST_PER_ITEM)
    monkeypatch.setenv("CLAUDE_BASE_URL", "https://gateway.test")
    assert collection.claude_model() == "deepseek-v4.1-flash"
    assert collection.cost_per_item() == pytest.approx(collection.CLAUDE_COST_PER_ITEM * 1.20 / 0.50)


def test_batch_is_blocked_through_a_gateway(monkeypatch):
    monkeypatch.setenv("CLAUDE_BASE_URL", "https://gateway.test")
    with pytest.raises(SystemExit, match="needs the Anthropic API"):
        cli._batch(None, SimpleNamespace(batch_command="submit"))
