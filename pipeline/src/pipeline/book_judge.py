"""Codex judges the book names and not_on_list words (TASK-83.16): which of them are real terms worth a definition.

    uv run pipeline books judge --dry-run     # how many rows are left after the free pre-filter, and the first message
    uv run pipeline books judge --limit 400   # Codex answers keep/drop and a short reason per row; run again to go on

`books collect` puts about 50k rows in the groups name and not_on_list. Most are character names and code
identifiers; tech terms (vue, nuxt, java) are in there too. The free pre-filter drops the obvious rows, Codex
reads the rest in batches with their example sentence, and the answer is saved on the row (judge, judge_reason).
Rows that already have a verdict are not sent again, so a stopped run goes on where it was. Keeps the developer has
not touched by hand get ticked, so `books review` shows them ready to write. Codex runs free on the ChatGPT plan.
"""

import json
import re
import sqlite3
from collections import Counter
from collections.abc import Callable
from dataclasses import dataclass, field

from pipeline import collection
from pipeline.book_words import MARK_END, MARK_START, NAME, NOT_ON_LIST

JUDGED_GROUPS = (NAME, NOT_ON_LIST)
BATCH_SIZE = 200
MIN_TIMES = 3  # fewer sightings than this: a typo, a broken line or a one-off name
MIN_BOOKS = 2  # seen in one book only: a character or a local variable
KEEP, DROP = "keep", "drop"
PRE = "pre-filter: "
CAMEL = re.compile(r"[a-z][A-Z]")
CONTROL = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")  # PDF text has null bytes; an argument cannot

JUDGE_SCHEMA = collection._strict({"verdicts": {"type": "array", "items": collection._strict({
    "id": {"type": "integer"}, "keep": {"type": "boolean"}, "reason": {"type": "string"}})}})

PROMPT = """You help a Vietnamese English learner. Below are words found in the books they read, each with one
example sentence (the word is inside [[double brackets]]). Decide for each word if it deserves a dictionary
definition in a learning app.

keep: a real English word or a real technical term a learner may look up: programming languages and frameworks
(Java, Vue, Nuxt), computing, science and engineering terms, and rare real words.
drop: a character name, a place or person name, a typo or broken word, a code identifier (a function, class or
variable name), a file name, a made-up word, or an abbreviation without a clear meaning.

Answer with one verdict per word, using the same id. The reason is at most 8 words."""


class JudgeWriter(collection.CodexWriter):
    """collection.CodexWriter (the same `codex exec` call, stop and error rules) with the verdicts schema."""

    schema = JUDGE_SCHEMA
    answer_key = "verdicts"


@dataclass
class Prefilter:
    keep: list[sqlite3.Row] = field(default_factory=list)  # rows that go to Codex
    dropped: Counter = field(default_factory=Counter)  # reason -> rows
    drops: list[tuple[int, str]] = field(default_factory=list)  # (row id, reason)


def marked_word(example: str) -> str:
    """The word as the book wrote it (camelCase is still there), taken from the marks in the example."""
    start, end = example.find(MARK_START), example.find(MARK_END)
    return example[start + 1:end] if 0 <= start < end else ""


def prefilter_reason(row: sqlite3.Row, fiction: tuple[str, ...]) -> str | None:
    """Why a row is dropped without asking Codex, or None."""
    if CAMEL.search(marked_word(row["example"] or "")):
        return "camelCase code"
    books = json.loads(row["books"] or "[]")
    if row["times"] < MIN_TIMES:
        return f"fewer than {MIN_TIMES} sightings"
    if len(books) < MIN_BOOKS:
        return "only one book"
    if row["book_group"] == NAME and fiction and all(any(k in b.lower() for k in fiction) for b in books):
        return "name seen only in fiction"
    return None


def prefilter(db: sqlite3.Connection, fiction: tuple[str, ...] = ()) -> Prefilter:
    """The rows without a verdict, split into the ones Codex should read and the ones dropped for free."""
    fiction = tuple(k.lower() for k in fiction)
    rows = db.execute("SELECT id, text, times, books, example, book_group FROM collection WHERE source = 'book' "
                      f"AND book_group IN ({','.join('?' * len(JUDGED_GROUPS))}) AND judge IS NULL "
                      "AND pushed_at IS NULL ORDER BY times DESC, text", JUDGED_GROUPS).fetchall()
    result = Prefilter()
    for row in rows:
        reason = prefilter_reason(row, fiction)
        if reason:
            result.dropped[reason] += 1
            result.drops.append((row["id"], reason))
        else:
            result.keep.append(row)
    return result


def save_drops(db: sqlite3.Connection, drops: list[tuple[int, str]]) -> None:
    db.executemany("UPDATE collection SET judge = ?, judge_reason = ? WHERE id = ?",
                   [(DROP, PRE + reason, row_id) for row_id, reason in drops])
    db.commit()


def build_prompt(rows: list[sqlite3.Row]) -> str:
    parts = [PROMPT, "<words>"]
    for row in rows:
        example = collection.escape_tags(CONTROL.sub("", row["example"] or "")).replace(MARK_START, "[[").replace(MARK_END, "]]")
        parts.append(f'<word id="{row["id"]}" times="{row["times"]}">{collection.escape_tags(CONTROL.sub("", row["text"]))} | '
                     f'{example}</word>')
    parts.append("</words>")
    return "\n".join(parts)


def save_verdicts(db: sqlite3.Connection, rows: list[sqlite3.Row], answers: list) -> int:
    """Saves the verdicts for the ids that were asked; a row Codex skipped stays without a verdict (tried again
    next run). A keep gets ticked unless the developer set the tick by hand. Returns the rows saved."""
    asked = {row["id"] for row in rows}
    saved = 0
    for answer in answers:
        if not isinstance(answer, dict) or answer.get("id") not in asked or not isinstance(answer.get("keep"), bool):
            continue
        verdict = KEEP if answer["keep"] else DROP
        reason = str(answer.get("reason", "")).strip()[:120]
        db.execute("UPDATE collection SET judge = ?, judge_reason = ? WHERE id = ?", (verdict, reason, answer["id"]))
        if verdict == KEEP:
            db.execute("UPDATE collection SET picked = 1 WHERE id = ? AND picked_by_hand = 0 AND pushed_at IS NULL",
                       (answer["id"],))
        saved += 1
    db.commit()
    return saved


def judge_rows(db: sqlite3.Connection, rows: list[sqlite3.Row], writer, batch_size: int = BATCH_SIZE,
               progress: Callable[[int, int, int], None] | None = None) -> tuple[int, int]:
    """Sends the rows to Codex in batches. Returns (verdicts saved, batches that failed). A ProviderStop (usage
    limit, not logged in) ends the run; what was saved stays."""
    saved = failed = 0
    for start in range(0, len(rows), batch_size):
        batch = rows[start:start + batch_size]
        try:
            answers = writer.write(build_prompt(batch))
        except collection.WriteError:
            failed += 1
            continue
        saved += save_verdicts(db, batch, answers)
        if progress:
            progress(min(start + batch_size, len(rows)), len(rows), saved)
    return saved, failed
