"""Command line entry point: `uv run app summarize FILE`."""

import argparse
import sys
import uuid
from pathlib import Path

import structlog

from app.config import get_settings
from app.llm import LLM, LLMError, make_client
from app.log import setup_logging
from app.summarize import summarize


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="app")
    sub = parser.add_subparsers(dest="command", required=True)
    p_sum = sub.add_parser("summarize", help="Summarize a text file (calls the LLM: costs money)")
    p_sum.add_argument("file", type=Path)
    args = parser.parse_args(argv)

    settings = get_settings()
    setup_logging(settings)
    structlog.contextvars.bind_contextvars(run_id=uuid.uuid4().hex[:12])
    log = structlog.get_logger()

    if args.command == "summarize":
        llm = LLM(make_client(settings), settings)
        try:
            result = summarize(llm, args.file.read_text(encoding="utf-8"))
        except LLMError as e:
            log.error("summarize_failed", error=str(e))
            return 1
        print(result.model_dump_json(indent=2))
        log.info("run_finished", spent_usd=round(llm.spent_usd, 6))
    return 0


if __name__ == "__main__":
    sys.exit(main())
