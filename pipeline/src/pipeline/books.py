"""Books to Markdown (TASK-83.14): every .pdf and .epub in a folder becomes a .md file, for the local collection.

    uv run pipeline books convert ~/Applications/Workspace/Books              # <book>.md next to each book
    uv run pipeline books convert ~/Applications/Workspace/Books --out ~/md   # same subfolders under ~/md

markitdown does the converting, on this Mac; nothing is sent anywhere. The text of a book is copyrighted, so the
.md files never go into the repo. A book that already has its .md is skipped, so the command can be stopped and run
again. Every .md (new or old) is checked, and books-report.tsv in the output folder says which ones are usable:

    ok           English text
    empty        fewer than MIN_WORDS words, usually a scanned PDF (needs OCR)
    not_english  more than MAX_NON_ASCII of the letters are not a-z, usually a Vietnamese book
    failed       markitdown could not read the file; no .md is written
"""

import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

BOOK_SUFFIXES = (".pdf", ".epub")
REPORT_NAME = "books-report.tsv"
MIN_WORDS = 1000
MAX_NON_ASCII = 0.05

OK = "ok"
EMPTY = "empty"
NOT_ENGLISH = "not_english"
FAILED = "failed"

ENGLISH_WORD = re.compile(r"[A-Za-z]+(?:['’][A-Za-z]+)*")


@dataclass
class Result:
    book: Path  # relative to the books folder
    status: str
    words: int
    converted: bool  # false: the .md was there already
    error: str = ""


def find_books(folder: Path) -> list[Path]:
    """Every .pdf and .epub under the folder, sorted, without hidden files or Office lock files (~$name)."""
    return sorted(
        path for path in folder.rglob("*")
        if path.is_file() and path.suffix.lower() in BOOK_SUFFIXES
        and not any(part.startswith((".", "~$")) for part in path.relative_to(folder).parts))


def markdown_path(book: Path, folder: Path, out: Path | None) -> Path:
    if out is None:
        return book.with_suffix(".md")
    return (out / book.relative_to(folder)).with_suffix(".md")


def classify(text: str) -> tuple[str, int]:
    """The status and the number of English words. Vietnamese has a mark on almost every word, English almost none."""
    words = len(ENGLISH_WORD.findall(text))
    letters = Counter(char.isascii() for char in text if char.isalpha())
    letter_count = letters[True] + letters[False]
    if letter_count and letters[False] / letter_count > MAX_NON_ASCII:
        return NOT_ENGLISH, words
    if words < MIN_WORDS:
        return EMPTY, words
    return OK, words


def markitdown_converter() -> Callable[[Path], str]:
    from markitdown import MarkItDown

    converter = MarkItDown(enable_plugins=False)
    return lambda path: converter.convert_local(str(path)).text_content


def convert_book(book: Path, target: Path, convert: Callable[[Path], str]) -> bool:
    """Writes the .md through a .part file, so a run that is stopped never leaves half a book that looks done.
    Returns false when the .md was there already."""
    if target.exists():
        return False
    text = convert(book)
    target.parent.mkdir(parents=True, exist_ok=True)
    part = target.with_name(target.name + ".part")
    part.write_text(text, encoding="utf-8")
    part.replace(target)
    return True


def convert_books(folder: Path, out: Path | None = None, convert: Callable[[Path], str] | None = None,
                  on_result: Callable[[int, int, Result], None] | None = None) -> list[Result]:
    books = find_books(folder)
    results = []
    for index, book in enumerate(books, start=1):
        target = markdown_path(book, folder, out)
        relative = book.relative_to(folder)
        try:
            if convert is None and not target.exists():
                convert = markitdown_converter()  # loaded only when there is something to convert
            converted = convert_book(book, target, convert)
            status, words = classify(target.read_text(encoding="utf-8", errors="replace"))
            result = Result(relative, status, words, converted)
        except Exception as error:  # markitdown raises many kinds; one bad book must not stop the rest
            result = Result(relative, FAILED, 0, False, f"{type(error).__name__}: {error}".splitlines()[0][:200])
        results.append(result)
        if on_result:
            on_result(index, len(books), result)
    return results


def write_report(results: list[Result], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = ["book\tstatus\twords\terror"]
    lines += [f"{r.book}\t{r.status}\t{r.words}\t{r.error}" for r in results]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def summary_line(results: list[Result]) -> str:
    counts = Counter(r.status for r in results)
    new = sum(r.converted for r in results)
    parts = [f"{counts[s]} {s}" for s in (OK, EMPTY, NOT_ENGLISH, FAILED) if counts[s]]
    return f"{len(results)} books ({new} converted now): " + ", ".join(parts or ["none"])
