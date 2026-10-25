"""Offline tests for the Codex judge of book names (TASK-83.16). A fake Codex, no network."""

import json

import pytest

from pipeline import book_judge as bj
from pipeline import book_words as bw
from pipeline import collection

M = bw.MARK_START, bw.MARK_END


@pytest.fixture
def db(tmp_path):
    connection = collection.connect(tmp_path / "pipeline.db")
    yield connection
    connection.close()


def add(db, text, group, times=5, books=("a.md", "b.md"), word=None, picked=0):
    example = f"We use {M[0]}{word or text.capitalize()}{M[1]} here."
    db.execute("INSERT INTO collection (kind, text, source, book_group, times, books, example, picked) "
               "VALUES ('word', ?, 'book', ?, ?, ?, ?, ?)", (text, group, times, json.dumps(list(books)), example, picked))
    db.commit()
    return db.execute("SELECT id FROM collection WHERE text = ?", (text,)).fetchone()[0]


class FakeCodex:
    def __init__(self, keep=()):
        self.keep, self.prompts = set(keep), []

    def write(self, prompt):
        self.prompts.append(prompt)
        ids = [int(i) for i in __import__("re").findall(r'<word id="(\d+)"', prompt)]
        return [{"id": i, "keep": i in self.keep, "reason": "a framework"} for i in ids]


def test_prefilter_drops_camel_case_rare_and_single_book_rows(db):
    add(db, "vue", bw.NAME)
    add(db, "getmapping", bw.NOT_ON_LIST, word="getMapping")
    add(db, "svidriga", bw.NAME, times=2)
    add(db, "raskol", bw.NAME, books=("a.md",))
    plan = bj.prefilter(db)
    assert [r["text"] for r in plan.keep] == ["vue"]
    assert set(plan.dropped) == {"camelCase code", "fewer than 3 sightings", "only one book"}


def test_prefilter_drops_names_seen_only_in_fiction(db):
    add(db, "dorian", bw.NAME, books=("novel-one.md", "novel-two.md"))
    add(db, "nuxt", bw.NAME, books=("novel-one.md", "vue-guide.md"))
    add(db, "zod", bw.NOT_ON_LIST, books=("novel-one.md", "novel-two.md"))
    plan = bj.prefilter(db, ("novel",))
    assert sorted(r["text"] for r in plan.keep) == ["nuxt", "zod"]  # the fiction rule is for the name group only


def test_judge_saves_verdicts_ticks_keeps_but_not_hand_changes(db):
    vue = add(db, "vue", bw.NAME)
    add(db, "raskol", bw.NAME)
    hand = add(db, "nuxt", bw.NAME)
    db.execute("UPDATE collection SET picked = 0, picked_by_hand = 1 WHERE id = ?", (hand,))
    rows = bj.prefilter(db).keep
    codex = FakeCodex(keep={vue, hand})
    saved, failed = bj.judge_rows(db, rows, codex)
    assert (saved, failed) == (3, 0)
    got = {r["text"]: (r["judge"], r["picked"], r["judge_reason"]) for r in db.execute("SELECT * FROM collection")}
    assert got["vue"] == ("keep", 1, "a framework")
    assert got["nuxt"][:2] == ("keep", 0)  # the developer unticked it by hand
    assert got["raskol"][:2] == ("drop", 0)


def test_judge_is_resumable_and_batches(db):
    for n in range(5):
        add(db, f"term{n}", bw.NOT_ON_LIST)
    codex = FakeCodex()
    bj.judge_rows(db, bj.prefilter(db).keep, codex, batch_size=2)
    assert len(codex.prompts) == 3
    assert bj.prefilter(db).keep == []  # everything has a verdict, nothing is sent again


def test_a_failed_batch_leaves_its_rows_without_a_verdict(db):
    add(db, "vue", bw.NAME)

    class Broken:
        def write(self, prompt):
            raise collection.WriteError("no answer")

    assert bj.judge_rows(db, bj.prefilter(db).keep, Broken()) == (0, 1)
    assert len(bj.prefilter(db).keep) == 1


def test_save_drops_marks_the_prefilter_reason(db):
    add(db, "raskol", bw.NAME, times=1)
    bj.save_drops(db, bj.prefilter(db).drops)
    row = db.execute("SELECT judge, judge_reason FROM collection").fetchone()
    assert tuple(row) == ("drop", "pre-filter: fewer than 3 sightings")


def test_prompt_marks_the_word_and_escapes_tags(db):
    add(db, "vue", bw.NAME)
    prompt = bj.build_prompt(bj.prefilter(db).keep)
    assert "vue | We use [[Vue]] here." in prompt


def test_a_name_group_book_word_is_pushed_as_needs_review(db):
    add(db, "vue", bw.NAME)
    add(db, "tiger", bw.COMMON)
    rows = {r["text"]: r for r in db.execute("SELECT * FROM collection")}
    assert collection.needs_review(rows["vue"]) and not collection.needs_review(rows["tiger"])


def test_review_items_carry_the_verdict(db):
    row_id = add(db, "vue", bw.NAME)
    db.execute("UPDATE collection SET judge = 'keep', judge_reason = 'framework' WHERE id = ?", (row_id,))
    item = bw.items_of_group(db, bw.NAME)[0]
    assert (item["judge"], item["reason"]) == ("keep", "framework")


def test_a_tick_by_hand_is_remembered(db):
    row_id = add(db, "vue", bw.NAME)
    bw.save_picks(db, [row_id], [])
    assert db.execute("SELECT picked, picked_by_hand FROM collection").fetchone()[:] == (1, 1)
