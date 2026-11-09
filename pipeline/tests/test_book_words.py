"""Offline tests for the words of the books (TASK-83.15). Fake text, fake word lists, no network, no Codex."""

import json
import threading
import urllib.error
import urllib.request

import pytest

from pipeline import book_words as bw
from pipeline import collection

ENGLISH = {"give", "up", "wander", "apple", "tiger", "obscure", "run", "house", "table", "quickly", "the", "dog",
           "grow", "road", "stone"}
ZIPF = {"wander": 4.2, "wandering": 4.1, "apple": 4.5, "tiger": 3.5, "obscure": 2.5, "grow": 5.0, "road": 5.0,
        "give up": 4.8}
TABLE = {"give up": "phrasal_verb", "break the ice": "idiom"}


def zipf_of(word):
    return ZIPF.get(word, 4.0)


def lemmas_for(word):
    return {"gave": {"give"}, "wandering": {"wander"}}.get(word, {word})


@pytest.fixture
def db(tmp_path):
    connection = collection.connect(tmp_path / "pipeline.db")
    yield connection
    connection.close()


def scan_of(*texts):
    scan = bw.Scan()
    finder = bw.PhraseFinder(TABLE, lemmas_for)
    for n, text in enumerate(texts):
        bw.scan_text(scan, f"book{n}.pdf", text, finder)
    return scan


def items_of(*texts, known=frozenset()):
    built = bw.build_items(scan_of(*texts), ENGLISH, set(known), zipf_of, TABLE, lemmas_for)
    return {i.text: i for i in built}


def test_groups_by_zipf_name_and_not_on_list():
    got = items_of("We saw an apple. The tiger ran. An obscure road. Then Mira left. Mira laughed. "
                   "A zorbble and a zorbble.")
    assert got["apple"].group == "common"
    assert got["tiger"].group == "uncommon"
    assert got["obscure"].group == "rare"
    assert got["mira"].group == "name"  # capitalised in the middle of a sentence, never in lower case
    assert got["zorbble"].group == "not_on_list"
    assert bw.group_for_zipf(4.0) == "common" and bw.group_for_zipf(3.0) == "uncommon"
    assert bw.group_for_zipf(2.99) == "rare"


def test_a_word_capitalised_only_at_the_start_of_a_sentence_is_not_a_name():
    got = items_of("Apple pie is good. Tiger stripes. I like an apple and a tiger.")
    assert got["apple"].group == "common" and got["tiger"].group == "uncommon"
    assert got["apple"].times == 2


def test_a_word_seen_once_that_is_not_on_the_list_is_dropped():
    assert "zorbble" not in items_of("A zorbble sat there.")


def test_forms_become_the_base_and_are_counted_together():
    got = items_of("He was wandering. He wanders. They wander on.")
    assert got["wander"].times == 3 and "wandering" not in got and "wanders" not in got


def test_known_forms_and_bases_are_skipped():
    got = items_of("The apples grow. A tiger sat.", known={"apple"})
    assert "apples" not in got and "apple" not in got and "tiger" in got
    assert "tiger" not in items_of("A tiger sat.", known={"tiger"})


def test_phrase_with_a_changed_first_word_and_the_example_marks_it():
    got = items_of("Last year she gave up the fight. He will give up too. Nothing else.")
    phrase = got["give up"]
    assert (phrase.group, phrase.kind, phrase.times) == ("phrase", "phrasal_verb", 2)
    assert "\x02gave up\x03" in phrase.example
    assert "give up" not in items_of("She gave\nup.")  # a line break ends a run


def test_example_is_one_sentence_of_at_most_25_words():
    long = "Before " + "word " * 60 + "obscure " + "word " * 60 + "after. Next sentence."
    example = items_of(long)["obscure"].example
    assert len(bw.plain_example(example).split()) <= 25 and "\x02obscure\x03" in example
    assert "Next" not in example


def test_ok_books_reads_only_ok_rows(tmp_path):
    (tmp_path / bw.REPORT_NAME).write_text("book\tstatus\twords\terror\na.pdf\tok\t5000\t\nb.pdf\tempty\t3\t\n"
                                           "sub/c.epub\tok\t7000\t\n")
    assert [(n, p.relative_to(tmp_path).as_posix()) for n, p in bw.ok_books(tmp_path)] == [
        ("a.pdf", "a.md"), ("sub/c.epub", "sub/c.md")]
    with pytest.raises(FileNotFoundError):
        bw.ok_books(tmp_path / "nope")


def run_collect(db, tmp_path, texts, known=frozenset(), cached=None):
    books = []
    for name, text in texts.items():
        path = tmp_path / name
        path.write_text(text)
        books.append((name + ".pdf", path))
    return bw.collect_books(db, books, english=ENGLISH, known=set(known), zipf_of=zipf_of, table=TABLE,
                            cached=cached, lemmas_for=lemmas_for)


def rows(db):
    return {r["text"]: r for r in db.execute("SELECT * FROM collection WHERE source = 'book'")}


def test_collect_saves_rows_with_defaults_and_skips_collection_and_server(db, tmp_path):
    db.execute("INSERT INTO collection (kind, text, source) VALUES ('word', 'tiger', 'scowl-70')")
    db.commit()
    text = "An apple. An obscure road. I gave up. Mira ran. Mira sat. A tiger. A house."
    result, scanned = run_collect(db, tmp_path, {"a.md": text}, known={"give"}, cached=lambda texts: {"house"})
    got = rows(db)
    assert set(got) == {"apple", "obscure", "road", "give up", "mira"}  # tiger: in collection; house: on server
    assert result.in_collection == 1 and scanned == ["a.md.pdf"]
    assert {t: r["picked"] for t, r in got.items()} == {"apple": 1, "give up": 1, "road": 1, "obscure": 0, "mira": 0}
    assert got["give up"]["kind"] == "phrasal_verb" and got["apple"]["status"] == "pending"
    assert json.loads(got["apple"]["books"]) == ["a.md.pdf"] and got["apple"]["times"] == 1


def test_running_again_adds_only_new_books_and_keeps_picks(db, tmp_path):
    run_collect(db, tmp_path, {"a.md": "An apple. An obscure road."})
    first = rows(db)
    bw.save_picks(db, [first["obscure"]["id"]], [first["apple"]["id"]])
    _, scanned = run_collect(db, tmp_path, {"a.md": "An apple. An obscure road.", "b.md": "Another apple. A tiger."})
    got = rows(db)
    assert scanned == ["b.md.pdf"]
    assert got["apple"]["times"] == 2 and json.loads(got["apple"]["books"]) == ["a.md.pdf", "b.md.pdf"]
    assert (got["apple"]["picked"], got["obscure"]["picked"]) == (0, 1)  # the picks survive
    assert "tiger" in got


def test_save_picks_changes_book_rows_only_and_not_pushed_ones(db, tmp_path):
    run_collect(db, tmp_path, {"a.md": "An apple. An obscure road."})
    db.execute("INSERT INTO collection (kind, text, source) VALUES ('word', 'plain', 'scowl-70')")
    db.execute("UPDATE collection SET pushed_at = CURRENT_TIMESTAMP WHERE text = 'road'")
    db.commit()
    got = rows(db)
    plain = db.execute("SELECT id FROM collection WHERE text = 'plain'").fetchone()[0]
    changed = bw.save_picks(db, [got["obscure"]["id"], plain], [got["apple"]["id"], got["road"]["id"]])
    assert changed == 2
    after = rows(db)
    assert (after["obscure"]["picked"], after["apple"]["picked"], after["road"]["picked"]) == (1, 0, 1)
    assert db.execute("SELECT picked FROM collection WHERE text = 'plain'").fetchone()[0] == 0


def test_write_and_push_take_picked_book_rows_only(db, tmp_path):
    run_collect(db, tmp_path, {"a.md": "An apple. An obscure road."})  # apple, road ticked; obscure not
    db.execute("INSERT INTO collection (kind, text, source) VALUES ('word', 'plain', 'scowl-70')")
    db.commit()
    assert {r["text"] for r in collection.rows_to_write(db, None, None, None, None)} == {"apple", "road", "plain"}
    assert {r["text"] for r in collection.rows_to_write(db, None, ["obscure"], None, None)} == set()
    entry = '{"senses":[{"pos":"noun","cefr":"A1","simpleDefinition":"x","vietnamese":"x","examples":[],"usage":[]}]}'
    db.execute("UPDATE collection SET status = 'done', entry = ?, model = 'codex:x'", (entry,))
    db.commit()
    assert {r["text"] for r in collection.push_rows(db, ["word"], False, None)} == {"apple", "road", "plain"}
    bw.save_picks(db, [], [rows(db)["road"]["id"]])  # unpick a written row: it leaves the push
    assert {r["text"] for r in collection.push_rows(db, ["word"], False, None)} == {"apple", "plain"}


def test_report_counts_per_group(db, tmp_path):
    run_collect(db, tmp_path, {"a.md": "An apple. An obscure road."})
    db.execute("UPDATE collection SET status = 'done' WHERE text = 'apple'")
    db.execute("UPDATE collection SET status = 'done', pushed_at = CURRENT_TIMESTAMP WHERE text = 'road'")
    db.commit()
    counts = bw.group_counts(db)
    assert dict(counts["common"]) == {"found": 2, "picked": 2, "written": 2, "pushed": 1}
    assert dict(counts["rare"]) == {"found": 1, "picked": 0, "written": 0, "pushed": 0}
    assert "common" in "\n".join(bw.report_lines(db))


def test_review_server_is_local_and_saves_picks(db, tmp_path):
    run_collect(db, tmp_path, {"a.md": "An apple. An obscure road."})
    server = bw.make_server(tmp_path / "pipeline.db", 0)
    assert server.server_address[0] == "127.0.0.1"
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{server.server_address[1]}"
    try:
        assert b"Book words" in urllib.request.urlopen(base + "/").read()
        groups = json.load(urllib.request.urlopen(base + "/api/groups"))
        assert {g["name"] for g in groups} == {"common", "rare"}
        items = json.load(urllib.request.urlopen(base + "/api/items?group=rare"))
        body = json.dumps({"picked": [items[0]["id"]], "unpicked": []}).encode()
        request = urllib.request.Request(base + "/api/picks", method="POST", data=body,
                                         headers={"Content-Type": "application/json"})
        assert json.load(urllib.request.urlopen(request)) == {"changed": 1}
        bad = urllib.request.Request(base + "/api/picks", method="POST", data=b"{}")  # no JSON content type
        with pytest.raises(urllib.error.HTTPError):
            urllib.request.urlopen(bad)
    finally:
        server.shutdown()
        server.server_close()
    assert rows(collection.connect(tmp_path / "pipeline.db"))["obscure"]["picked"] == 1


def test_a_not_on_list_book_word_is_pushed_as_needs_review_but_a_hard_word_alone_is_not(db):
    db.execute("INSERT INTO collection (kind, text, source, priority, status, book_group) "
               "VALUES ('word', 'vue', 'book', 0, 'done', 'not_on_list'), ('word', 'wander', 'book', 0, 'done', 'common'), "
               "('word', 'abide', 'scowl-70', 0, 'needs_review', NULL)")
    rows = {r["text"]: r for r in db.execute("SELECT * FROM collection")}
    assert [collection.needs_review(rows[t]) for t in ("vue", "wander", "abide")] == [True, False, False]
