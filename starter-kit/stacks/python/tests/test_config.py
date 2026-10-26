import pytest
from pydantic import ValidationError

from app.config import Settings


def test_secret_is_hidden_when_printed() -> None:
    s = Settings(_env_file=None, anthropic_api_key="sk-secret")  # pyright: ignore[reportCallIssue, reportArgumentType]
    assert "sk-secret" not in repr(s)


def test_wrong_value_fails_at_start(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "prod")  # not one of local/staging/production
    with pytest.raises(ValidationError):
        Settings(_env_file=None)  # pyright: ignore[reportCallIssue]
