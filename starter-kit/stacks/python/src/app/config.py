"""All settings in one typed object, read from env vars (and .env locally). Fails at start if wrong."""

from functools import lru_cache
from typing import Literal

from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: Literal["local", "staging", "production"] = "local"
    log_format: Literal["text", "json"] = "text"
    log_level: str = "INFO"

    # SecretStr: printing settings shows '**********', never the key.
    anthropic_api_key: SecretStr | None = None
    llm_model: str = "claude-opus-5-5"
    llm_timeout_seconds: float = Field(default=120, gt=0)
    llm_max_retries: int = Field(default=3, ge=0, le=10)
    # Hard stop for one run (one CLI command / one job), in US dollars.
    llm_budget_usd: float = Field(default=1.0, ge=0)


@lru_cache
def get_settings() -> Settings:
    return Settings()
