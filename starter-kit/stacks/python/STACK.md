### Python (`python/`, Python 3.13, uv, ruff, pyright strict, pytest, pydantic-settings, structlog)

- `src/` layout, one module per job (`summarize.py`), entry points in `cli.py`. Settings only from
  `config.py` (`Settings`, typed, `SecretStr` for keys). Logs only through structlog (`log.info("event", key=value)`).
- **Every LLM call goes through `llm.py` (`LLM.ask`)**: budget, timeouts, retries, prompt name+version,
  structured output, caching, cost log. A prompt text change bumps `Prompt.version`.
- Agents never run paid jobs (real LLM calls, big batches). Write the code and tests with a fake client;
  say the command and its rough cost.
- Long jobs save progress (SQLite or a status column) so they can resume after a crash.
- `make -C python check` = ruff + format + pyright + pytest. One file: `make -C python test F=tests/test_llm.py`.
