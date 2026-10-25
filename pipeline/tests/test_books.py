"""Offline tests for books to Markdown (TASK-83.14). The converter is a fake, so markitdown never runs."""

from pathlib import Path

from pipeline import books

ENGLISH = "The quick brown fox jumps over the lazy dog. " * 200  # 1,800 words


def make_books(folder: Path, *names: str) -> None:
    for name in names:
        path = folder / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"%PDF fake")


def fake(texts: dict[str, str], calls: list[str]):
    def convert(path: Path) -> str:
        calls.append(path.name)
        if texts[path.name] is None:
            raise ValueError("cannot read this file\nsecond line")
        return texts[path.name]
    return convert


def test_only_pdf_and_epub_are_found_without_hidden_and_lock_files(tmp_path):
    make_books(tmp_path, "a.pdf", "Novels/b.EPUB", "c.docx", ".hidden/d.pdf", "~$e.pdf", "f.md")
    assert [p.relative_to(tmp_path).as_posix() for p in books.find_books(tmp_path)] == ["Novels/b.EPUB", "a.pdf"]


def test_the_md_goes_next_to_the_book_or_under_out_with_the_same_subfolders(tmp_path):
    book = tmp_path / "Novels" / "b.epub"
    assert books.markdown_path(book, tmp_path, None) == tmp_path / "Novels" / "b.md"
    assert books.markdown_path(book, tmp_path, tmp_path / "out") == tmp_path / "out" / "Novels" / "b.md"


def test_classify_english_empty_and_vietnamese():
    assert books.classify(ENGLISH) == (books.OK, 1800)
    assert books.classify("Chapter 1\n\n12") == (books.EMPTY, 1)
    status, _ = books.classify("Những tù nhân của địa lý. Người đọc sẽ hiểu được thế giới. " * 100)
    assert status == books.NOT_ENGLISH


def test_a_book_with_its_md_is_skipped_but_still_checked(tmp_path):
    make_books(tmp_path, "a.pdf", "b.pdf")
    (tmp_path / "a.md").write_text(ENGLISH)
    calls = []
    results = books.convert_books(tmp_path, convert=fake({"b.pdf": ENGLISH}, calls))
    assert calls == ["b.pdf"]
    assert [(str(r.book), r.status, r.converted) for r in results] == [("a.pdf", "ok", False), ("b.pdf", "ok", True)]
    assert (tmp_path / "b.md").read_text() == ENGLISH
    assert not list(tmp_path.glob("*.part"))


def test_a_failed_book_writes_no_md_and_the_rest_go_on(tmp_path):
    make_books(tmp_path, "a.pdf", "b.pdf")
    results = books.convert_books(tmp_path, convert=fake({"a.pdf": None, "b.pdf": ""}, []))
    assert [(r.status, r.error) for r in results] == [
        (books.FAILED, "ValueError: cannot read this file"), (books.EMPTY, "")]
    assert not (tmp_path / "a.md").exists()
    # A scanned PDF keeps its (empty) .md, so the next run does not spend time on it again.
    assert (tmp_path / "b.md").exists()


def test_report_and_summary(tmp_path):
    make_books(tmp_path, "a.pdf", "b.pdf")
    results = books.convert_books(tmp_path, convert=fake({"a.pdf": ENGLISH, "b.pdf": None}, []))
    books.write_report(results, tmp_path / books.REPORT_NAME)
    lines = (tmp_path / books.REPORT_NAME).read_text().splitlines()
    assert lines[0] == "book\tstatus\twords\terror"
    assert lines[1] == "a.pdf\tok\t1800\t"
    assert books.summary_line(results) == "2 books (1 converted now): 1 ok, 1 failed"
