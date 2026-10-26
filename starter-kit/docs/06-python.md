# 06. Python: uv, ruff, pyright, pydantic

Template: `stacks/python/`. Built and tested: ruff, ruff format, pyright **strict**, 6 pytest tests.

## Toolchain (one tool per job)

| Job | Tool | Note |
|---|---|---|
| Python versions, venv, deps, lock | `uv` | `uv add x`, `uv run pytest`; `uv.lock` is committed |
| Lint + format | `ruff` | Replaces flake8, isort, black. Rules: E/F/I/B/UP/SIM/S/RUF |
| Types | `pyright` (strict) | Agents write fewer `Any`s when strict mode complains |
| Tests | `pytest` | Plain functions and fixtures |
| Settings | `pydantic-settings` | Typed, validated at start; `SecretStr` hides keys in logs |
| Logs | `structlog` | Key-value events; JSON in prod; `run_id` bound once with contextvars |
| Data shapes | `pydantic` models | Also the schema for LLM structured output |

## Structure

```
python/
├── pyproject.toml        deps + ruff + pyright + pytest config, all in one file
├── src/app/
│   ├── config.py         Settings (env vars → typed object)
│   ├── log.py            structlog setup
│   ├── llm.py            the only door to the LLM (see doc 11)
│   ├── summarize.py      a feature: Prompt + pydantic output + one function
│   └── cli.py            argparse entry point: `uv run app summarize FILE`
└── tests/                fake LLM client, no network
```

`src/` layout stops tests from importing the code by accident from the working folder.

## Habits for data and pipeline jobs (from Saynata's `pipeline/`)

- **Every step can resume.** Save progress (SQLite table or a status column) after each item.
  A crash at item 9,000 must not mean starting again (Saynata's `pipeline.db`).
- **Dry run first.** `--limit 10` and `--dry-run` flags on every paid or slow command.
- **Budget before batch**: estimate the cost (tokens × price) and print it before you start. Stop at the budget.
- Batch API (50% cheaper) for big, non-urgent LLM jobs.
- Agents write the code and the tests, then *say* the command and its cost. You run paid jobs yourself.

## Real examples

- `astral-sh/uv` and `ruff` docs (*Configuring Ruff*, *Projects*).
- `fastapi/full-stack-fastapi-template`: uv, pydantic-settings, Alembic, tests, Docker.
- `hynek/structlog` docs, *Best practices*.
- This repo: `pipeline/` (Saynata): resumable steps in `cli.py`, LLM calls through `llm.py`.
