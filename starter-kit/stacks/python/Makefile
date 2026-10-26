.PHONY: check test format
check:   ## what CI runs
	uv run ruff check . && uv run ruff format --check . && uv run pyright && uv run pytest
test:    ## one file: make test F=tests/test_llm.py
	uv run pytest $(F)
format:
	uv run ruff check --fix . && uv run ruff format .
