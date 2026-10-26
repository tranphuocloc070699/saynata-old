"""Words and phrases from the books (TASK-83.15): collect, tick by hand, then write with Codex and push. All free.

    uv run pipeline books collect ~/Applications/Workspace/Books   # new words and phrases into pipeline.db, grouped
    uv run pipeline books review                                    # a page on 127.0.0.1 to tick what to keep
    uv run pipeline books report                                    # per group: found / picked / written / pushed
    uv run pipeline collection write --limit 20                     # Codex writes the ticked rows only
    uv run pipeline collection push                                 # dry run; --yes writes to the VPS word_lookup

The rules copy the backend's SourceAnalyzer (sources/): names, base forms, phrases whose first word is a form.
The input is the .md files of `books convert` (books.py). The book text stays on this Mac; only the ticked words,
once written, go to the server. Book rows live in the `collection` table with source 'book' (collection.py).

Groups:
    name         never written in lower case, and capitalised in the middle of a sentence (or not a word at all)
    common       Zipf >= 4          uncommon   3 <= Zipf < 4          rare   Zipf < 3
    phrase       a WordNet phrasal verb or idiom found in the text
    not_on_list  not on the backend word list (scowl-70 + ngsl): the backend answers "not a word" for these
Common and phrase start ticked; the other groups start unticked.
"""

import json
import re
import sqlite3
import threading
import webbrowser
from collections import Counter
from collections.abc import Callable
from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from pipeline.books import OK, REPORT_NAME, markdown_path

NAME = "name"
COMMON = "common"
UNCOMMON = "uncommon"
RARE = "rare"
PHRASE = "phrase"
NOT_ON_LIST = "not_on_list"
GROUPS = (COMMON, PHRASE, UNCOMMON, RARE, NAME, NOT_ON_LIST)
TICKED_AT_FIRST = (COMMON, PHRASE)
COMMON_ZIPF = 4.0
UNCOMMON_ZIPF = 3.0
MAX_EXAMPLE_WORDS = 25
MIN_WORD_LENGTH = 3
MIN_NOT_ON_LIST_TIMES = 2  # one sighting of an unknown word is almost always a typo or a broken line
BASE_ZIPF_MARGIN = 1.0  # a base wins when it is within this Zipf of the form ("wandering" -> "wander")
MARK_START, MARK_END = "\x02", "\x03"  # around the word in an example; the review page turns them into <mark>

TOKEN = re.compile(r"[A-Za-z]+(?:['’][A-Za-z]+)*")
SENTENCE_END = ".!?…"
OPENERS = "\"'“‘([*_#>`- \t"
MARKDOWN = re.compile(r"[*_#>`]")
LOWER, UPPER, CAP_START, CAP_MID = "lower", "upper", "cap_start", "cap_mid"


# ---------- tokens (SourceAnalyzer.tokenize) ----------


@dataclass(frozen=True)
class Token:
    lower: str
    contraction: bool
    start: int
    end: int
    kind: str


def starts_sentence(text: str, index: int) -> bool:
    """True at the start of the text or a line, or after . ! ? (quotes and markdown marks in between are ignored)."""
    i = index - 1
    while i >= 0 and text[i] in OPENERS:
        i -= 1
    return i < 0 or text[i] in "\n\r" or text[i] in SENTENCE_END


def kind_of(raw: str, sentence_start: bool) -> str:
    if len(raw) > 1 and raw == raw.upper():
        return UPPER
    if raw[0].islower():
        return LOWER
    if raw[1:] == raw[1:].lower() and sentence_start:
        return CAP_START
    return CAP_MID


def tokenize(text: str) -> list[Token]:
    """A trailing 's is dropped; a word with another apostrophe is a contraction."""
    tokens = []
    for match in TOKEN.finditer(text):
        raw = match.group().replace("’", "'")
        if len(raw) > 2 and raw.lower().endswith("'s"):
            raw = raw[:-2]
        tokens.append(Token(raw.lower(), "'" in raw, match.start(), match.end(),
                            kind_of(raw, starts_sentence(text, match.start()))))
    return tokens


def candidate_bases(word: str) -> list[str]:
    """SentenceWordQueue.candidateBases: the same endings the backend queue uses."""
    out: dict[str, None] = {}
    n = len(word)

    def undoubled(stem: str) -> None:
        if len(stem) > 2 and stem[-1] == stem[-2]:
            out[stem[:-1]] = None

    if word.endswith("ies") and n > 4:
        out[word[:-3] + "y"] = None
    if word.endswith("es") and n > 3:
        out[word[:-2]] = None
    if word.endswith("s") and not word.endswith("ss") and n > 3:
        out[word[:-1]] = None
    if word.endswith("ing") and n > 5:
        stem = word[:-3]
        out[stem] = None
        out[stem + "e"] = None
        undoubled(stem)
    if word.endswith("ied") and n > 4:
        out[word[:-3] + "y"] = None
    if word.endswith("ed") and n > 4:
        stem = word[:-2]
        out[stem] = None
        out[stem + "e"] = None
        undoubled(stem)
    out.pop(word, None)
    return list(out)


def sentence_around(text: str, start: int, end: int, max_words: int = MAX_EXAMPLE_WORDS) -> str:
    """The sentence that holds text[start:end], cut to `max_words` words around the word. The word is wrapped in
    MARK_START / MARK_END. Markdown marks are removed."""
    left = start
    while left > 0 and start - left < 600 and text[left - 1] not in "\n\r" and text[left - 1] not in SENTENCE_END:
        left -= 1
    right = end
    while right < len(text) and right - end < 600 and text[right] not in "\n\r":
        right += 1
        if text[right - 1] in SENTENCE_END:
            break
    before = MARKDOWN.sub("", text[left:start]).split()
    word = MARKDOWN.sub("", text[start:end]).strip()
    after = MARKDOWN.sub("", text[end:right]).split()
    room = max(0, max_words - len(word.split()))
    keep_after = min(len(after), max(room // 2, room - len(before)))
    keep_before = min(len(before), room - keep_after)
    before = before[len(before) - keep_before:] if keep_before else []
    return " ".join([*before, f"{MARK_START}{word}{MARK_END}", *after[:keep_after]])


def plain_example(example: str) -> str:
    return example.replace(MARK_START, "").replace(MARK_END, "")


# ---------- scan ----------


@dataclass
class FormStat:
    times: int = 0
    lower_or_upper: int = 0
    cap_mid: int = 0
    books: dict[str, None] = field(default_factory=dict)  # an ordered set
    example: str = ""


@dataclass
class PhraseStat:
    times: int = 0
    books: dict[str, None] = field(default_factory=dict)
    example: str = ""


@dataclass
class Scan:
    forms: dict[str, FormStat] = field(default_factory=dict)
    phrases: dict[str, PhraseStat] = field(default_factory=dict)
    books: list[str] = field(default_factory=list)


def default_lemmas(word: str) -> set[str]:
    from pipeline.prefill import lemmas_of

    return lemmas_of(word)


class PhraseFinder:
    """Phrases of 2 to 4 words in a row, from the table `{phrase: kind}`. The first word may be a form ("gave up"
    finds "give up"): its choices are itself, its base forms and every lemma lemminflect knows."""

    def __init__(self, table: dict[str, str], lemmas_for: Callable[[str], set[str]] = default_lemmas):
        self.table = table
        self.lemmas_for = lemmas_for
        self.first_words = {phrase.split(" ", 1)[0] for phrase in table}
        self._choices: dict[str, list[str]] = {}

    def first_choices(self, word: str) -> list[str]:
        if word not in self._choices:
            found = {word, *candidate_bases(word), *self.lemmas_for(word)}
            self._choices[word] = sorted(choice for choice in found if choice in self.first_words)
        return self._choices[word]

    def find(self, text: str, tokens: list[Token]) -> list[tuple[str, int, int]]:
        """(phrase, start, end) for each match; the longest phrase at a place wins."""
        found = []
        for i in range(len(tokens) - 1):
            if tokens[i].contraction:
                continue
            choices = self.first_choices(tokens[i].lower)
            if not choices:
                continue
            for length in (4, 3, 2):
                if not self._is_run(text, tokens, i, length):
                    continue
                rest = " ".join(t.lower for t in tokens[i + 1:i + length])
                match = next((f"{c} {rest}" for c in choices if f"{c} {rest}" in self.table), None)
                if match:
                    found.append((match, tokens[i].start, tokens[i + length - 1].end))
                    break
        return found

    @staticmethod
    def _is_run(text: str, tokens: list[Token], start: int, length: int) -> bool:
        """Neighbours: only spaces between the words, no contractions."""
        if start + length > len(tokens):
            return False
        return not any(tokens[i].contraction or text[tokens[i - 1].end:tokens[i].start].strip(" \t")
                       for i in range(start + 1, start + length))


def phrase_table(lemmas: dict[str, set[str]]) -> dict[str, str]:
    """WordNet multiword lemmas as `{phrase: kind}` (phrasal_verb or idiom), the filters of `collection collect`."""
    from pipeline import collection, prefill

    table = {}
    for lemma, parts in lemmas.items():
        text = prefill.normalize_phrase(lemma)
        if text and parts & prefill.PHRASE_POS and collection.allowed_phrase(text) and text not in table:
            table[text] = collection.phrase_kind(text, parts)
    return table


def scan_text(scan: Scan, book: str, text: str, finder: PhraseFinder | None) -> None:
    """Counts the words and phrases of one book into `scan`, keeping the first sentence of each as its example."""
    tokens = tokenize(text)
    for token in tokens:
        if token.contraction or len(token.lower) < 2:
            continue
        stat = scan.forms.setdefault(token.lower, FormStat())
        stat.times += 1
        stat.books[book] = None
        if not stat.example:
            stat.example = sentence_around(text, token.start, token.end)
        if token.kind in (LOWER, UPPER):
            stat.lower_or_upper += 1
        elif token.kind == CAP_MID:
            stat.cap_mid += 1
    if finder:
        for phrase, start, end in finder.find(text, tokens):
            stat = scan.phrases.setdefault(phrase, PhraseStat())
            stat.times += 1
            stat.books[book] = None
            if not stat.example:
                stat.example = sentence_around(text, start, end)
    scan.books.append(book)


# ---------- items ----------


@dataclass
class BookItem:
    kind: str  # word | phrasal_verb | idiom
    text: str
    group: str
    zipf: float
    times: int
    books: list[str]
    example: str

    @property
    def picked(self) -> bool:
        return self.group in TICKED_AT_FIRST


def group_for_zipf(zipf: float) -> str:
    return COMMON if zipf >= COMMON_ZIPF else UNCOMMON if zipf >= UNCOMMON_ZIPF else RARE


def is_name(form: str, stat: FormStat, english: set[str]) -> bool:
    """Never written in lower case, and either capitalised mid-sentence or not a real word."""
    return stat.lower_or_upper == 0 and (stat.cap_mid > 0 or form not in english)


def choose_lemma(form: str, form_is_word: bool, bases: list[str], zipf_of: Callable[[str], float]) -> str:
    """A base wins when it is about as common as the form."""
    if not bases:
        return form
    best = max(bases, key=zipf_of)
    if not form_is_word:
        return best
    base_zipf = zipf_of(best)
    return best if base_zipf > 0 and base_zipf >= zipf_of(form) - BASE_ZIPF_MARGIN else form


def build_items(scan: Scan, english: set[str], known: set[str], zipf_of: Callable[[str], float],
                table: dict[str, str] | None = None, lemmas_for: Callable[[str], set[str]] = default_lemmas,
                blocked: set[str] | None = None) -> list[BookItem]:
    """The new words and phrases of the scan. `known` (lowercase) holds the bundled words, the pipeline words and
    the words already cached on the server. A form is skipped when it or any of its bases is known."""
    from pipeline import collection

    blocked = collection.BLOCKED_WORDS if blocked is None else blocked
    words: dict[str, BookItem] = {}
    for form, stat in scan.forms.items():
        if not form.isascii() or not form.isalpha() or form in blocked:
            continue
        if is_name(form, stat, english):
            if form not in known and len(form) >= MIN_WORD_LENGTH:
                words[form] = BookItem("word", form, NAME, 0.0, stat.times, list(stat.books), stat.example)
            continue
        form_is_word = form in english
        bases = [b for b in dict.fromkeys([*candidate_bases(form), *lemmas_for(form)]) if b != form and b in english]
        if not form_is_word and not bases:
            if stat.times >= MIN_NOT_ON_LIST_TIMES and len(form) >= MIN_WORD_LENGTH and form not in known:
                words[form] = BookItem("word", form, NOT_ON_LIST, zipf_of(form), stat.times, list(stat.books),
                                       stat.example)
            continue
        if form in known or any(base in known for base in bases):
            continue
        lemma = choose_lemma(form, form_is_word, bases, zipf_of)
        if len(lemma) < MIN_WORD_LENGTH or lemma in known or lemma in blocked:
            continue
        if lemma in words and words[lemma].group != NAME:
            merged = words[lemma]
            merged.times += stat.times
            merged.books = list(dict.fromkeys([*merged.books, *stat.books]))
        else:
            zipf = zipf_of(lemma)
            words[lemma] = BookItem("word", lemma, group_for_zipf(zipf), zipf, stat.times, list(stat.books),
                                    stat.example)
    items = list(words.values())
    for phrase, stat in scan.phrases.items():
        if phrase not in known:
            kind = (table or {}).get(phrase, "idiom")
            items.append(BookItem(kind, phrase, PHRASE, zipf_of(phrase), stat.times, list(stat.books), stat.example))
    return sorted(items, key=lambda i: (-i.times, i.text))


def server_cached(pg, texts: list[str], prompt_version: str, chunk: int = 5000) -> set[str]:
    """The texts that already have a word_lookup row on the server (read-only)."""
    from pipeline import collection

    found: set[str] = set()
    for i in range(0, len(texts), chunk):
        keys = {collection.cache_key(text, prompt_version): text for text in texts[i:i + chunk]}
        with pg.cursor() as cursor:
            cursor.execute("SELECT cache_key FROM word_lookup WHERE cache_key = ANY(%s)", (list(keys),))
            found |= {keys[row[0]] for row in cursor.fetchall()}
    return found


def ok_books(folder: Path, out: Path | None = None) -> list[tuple[str, Path]]:
    """(book name, .md path) for each `ok` row of books-report.tsv."""
    report = (out or folder) / REPORT_NAME
    if not report.is_file():
        raise FileNotFoundError(f"{report} is missing. Run: uv run pipeline books convert {folder}")
    rows = [line.split("\t") for line in report.read_text(encoding="utf-8").splitlines()[1:] if line.strip()]
    return [(row[0], markdown_path(folder / row[0], folder, out)) for row in rows if row[1] == OK]


# ---------- save ----------


@dataclass
class SaveResult:
    new: Counter = field(default_factory=Counter)  # per group
    updated: int = 0  # book rows that exist: more sightings added, pick kept
    in_collection: int = 0  # the text is in the collection from another source: left alone


def save_items(db: sqlite3.Connection, items: list[BookItem], scanned: list[str]) -> SaveResult:
    """Adds the new rows (source 'book'; picked only for common and phrase). A book row that exists gets the new
    sightings and keeps its pick. Marks the books as collected."""
    from pipeline import collection

    result = SaveResult()
    for item in items:
        row = db.execute("SELECT id, source, times, books FROM collection WHERE text = ?", (item.text,)).fetchone()
        if row is None:
            db.execute(
                "INSERT INTO collection (kind, text, source, zipf, priority, book_group, times, books, example, picked) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (item.kind, item.text, collection.SOURCE_BOOK, round(item.zipf, 3), round(item.zipf * 100),
                 item.group, item.times, json.dumps(item.books), item.example, int(item.picked)))
            result.new[item.group] += 1
        elif row["source"] == collection.SOURCE_BOOK:
            seen = list(dict.fromkeys([*json.loads(row["books"] or "[]"), *item.books]))
            db.execute("UPDATE collection SET times = ?, books = ? WHERE id = ?",
                       (row["times"] + item.times, json.dumps(seen), row["id"]))
            result.updated += 1
        else:
            result.in_collection += 1
    db.executemany("INSERT OR IGNORE INTO book_done (book) VALUES (?)", [(book,) for book in scanned])
    db.commit()
    return result


def collect_books(db: sqlite3.Connection, books: list[tuple[str, Path]], *, english: set[str], known: set[str],
                  zipf_of: Callable[[str], float], table: dict[str, str] | None = None,
                  cached: Callable[[list[str]], set[str]] | None = None,
                  lemmas_for: Callable[[str], set[str]] = default_lemmas,
                  on_book: Callable[[int, int, str], None] | None = None) -> tuple[SaveResult, list[str]]:
    """Reads the books that were not collected before and saves their new words and phrases.
    Returns (what was saved, the books read). `cached` asks the server which texts it has already."""
    done = {row[0] for row in db.execute("SELECT book FROM book_done")}
    todo = [(name, path) for name, path in books if name not in done]
    finder = PhraseFinder(table, lemmas_for) if table else None
    scan = Scan()
    for index, (name, path) in enumerate(todo, start=1):
        scan_text(scan, name, path.read_text(encoding="utf-8", errors="replace"), finder)
        if on_book:
            on_book(index, len(todo), name)
    items = build_items(scan, english, known, zipf_of, table, lemmas_for)
    if cached and items:
        on_server = cached([item.text for item in items])
        items = [item for item in items if item.text not in on_server]
    return save_items(db, items, scan.books), scan.books


# ---------- report ----------


def group_counts(db: sqlite3.Connection) -> dict[str, Counter]:
    """Per group: found, picked, written (Codex wrote it), pushed."""
    counts: dict[str, Counter] = {}
    rows = db.execute("SELECT book_group, picked, status, pushed_at IS NOT NULL FROM collection WHERE source = 'book'")
    for group, picked, status, pushed in rows:
        c = counts.setdefault(group, Counter())
        c["found"] += 1
        c["picked"] += picked
        c["written"] += status in ("done", "needs_review")
        c["pushed"] += pushed
    return counts


def report_lines(db: sqlite3.Connection) -> list[str]:
    counts = group_counts(db)
    if not counts:
        return ["No book words yet. Run: uv run pipeline books collect <folder>"]
    head = f"{'group':<13}{'found':>9}{'picked':>9}{'written':>9}{'pushed':>9}"
    lines = [head, "-" * len(head)]
    total: Counter = Counter()
    for group in GROUPS:
        if group in counts:
            c = counts[group]
            total.update(c)
            lines.append(f"{group:<13}{c['found']:>9}{c['picked']:>9}{c['written']:>9}{c['pushed']:>9}")
    lines += ["-" * len(head),
              f"{'all':<13}{total['found']:>9}{total['picked']:>9}{total['written']:>9}{total['pushed']:>9}"]
    waiting = db.execute("SELECT count(*) FROM collection WHERE source = 'book' AND picked = 1 "
                         "AND status IN ('pending', 'failed')").fetchone()[0]
    lines += ["", f"Picked and waiting for Codex: {waiting}. Next: uv run pipeline collection write --limit 20"]
    return lines


# ---------- review (a page on this Mac only) ----------


def items_of_group(db: sqlite3.Connection, group: str) -> list[dict]:
    rows = db.execute("SELECT id, text, kind, times, books, example, picked, status, judge, judge_reason, "
                      "pushed_at IS NOT NULL AS pushed "
                      "FROM collection WHERE source = 'book' AND book_group = ? ORDER BY times DESC, text", (group,))
    return [{"id": r["id"], "text": r["text"], "kind": r["kind"], "times": r["times"],
             "books": json.loads(r["books"] or "[]"), "example": r["example"] or "", "picked": r["picked"],
             "status": r["status"], "pushed": r["pushed"], "judge": r["judge"] or "",
             "reason": r["judge_reason"] or ""} for r in rows]


def save_picks(db: sqlite3.Connection, picked: list[int], unpicked: list[int]) -> int:
    """Saves the ticks. Only book rows; a row that is already pushed keeps its pick. Returns the rows changed."""
    changed = 0
    for value, ids in ((1, picked), (0, unpicked)):
        for row_id in ids:
            changed += db.execute("UPDATE collection SET picked = ?, picked_by_hand = 1 WHERE id = ? AND source = 'book' "
                                  "AND pushed_at IS NULL AND picked != ?", (value, int(row_id), value)).rowcount
    db.commit()
    return changed


PAGE = r"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>Book words</title>
<style>
:root{--bg:#fafaf8;--card:#fff;--ink:#1d1d1b;--soft:#6b6b66;--line:#e4e2dc;--teal:#0f766e;--mark:#fde68a}
@media (prefers-color-scheme: dark){:root{--bg:#151514;--card:#1f1f1d;--ink:#ecebe6;--soft:#a3a29c;--line:#34332f;
--teal:#2dd4bf;--mark:#713f12}}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 -apple-system,system-ui,sans-serif}
main{max-width:1000px;margin:0 auto;padding:24px 16px 80px} h1{font-size:22px;margin:0 0 4px}
.intro{color:var(--soft);margin:0 0 16px} .tabs{display:flex;flex-wrap:wrap;gap:8px;margin:0 0 12px}
.tab{border:1px solid var(--line);background:var(--card);color:var(--ink);border-radius:20px;padding:6px 14px;cursor:pointer}
.tab.on{background:var(--teal);color:#fff;border-color:var(--teal)}
.bar{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin:0 0 12px;position:sticky;top:0;background:var(--bg);
padding:8px 0;z-index:1}
input[type=search]{flex:1;min-width:180px;padding:6px 10px;border:1px solid var(--line);border-radius:8px;
background:var(--card);color:var(--ink)}
button.act{border:1px solid var(--line);background:var(--card);color:var(--ink);border-radius:8px;padding:6px 12px;cursor:pointer}
button.save{background:var(--teal);color:#fff;border-color:var(--teal)}
.row{display:flex;gap:10px;background:var(--card);border:1px solid var(--line);border-radius:10px;padding:10px 12px;
margin:0 0 8px} .row input{margin-top:5px} .w{font-weight:600;font-size:16px}
.meta{color:var(--soft);font-size:12px} .ex{margin:2px 0 0;color:var(--soft)} mark{background:var(--mark);color:inherit}
.tag{color:var(--teal);font-size:12px} #msg{color:var(--soft);font-size:13px}
</style></head><body><main><h1>Book words</h1>
<p class="intro">Tick what to keep, then Save. Only ticked words are written by Codex and pushed. Nothing leaves this Mac here.</p>
<div class="tabs" id="tabs"></div>
<div class="bar"><input type="search" id="q" placeholder="Search">
<select id="verdict" class="act"><option value="">All verdicts</option><option value="keep">Codex: keep</option>
<option value="drop">Codex: drop</option><option value="none">Not judged</option></select>
<button class="act" id="all">Tick all</button><button class="act" id="none">Untick all</button>
<button class="act save" id="save">Save</button><span id="msg"></span></div>
<div id="list"></div><button class="act" id="more" hidden>Show more</button></main>
<script>
const PAGE_SIZE = 200;
let groups = [], current = null, items = [], shown = PAGE_SIZE;
const changes = new Map();  // id -> 1 or 0, not saved yet
const $ = id => document.getElementById(id);
const esc = s => s.replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const mark = s => esc(s).replace(/\u0002/g, '<mark>').replace(/\u0003/g, '</mark>');
const matching = () => { const q = $('q').value.trim().toLowerCase(), v = $('verdict').value;
  return items.filter(i => (!q || i.text.includes(q) || i.example.toLowerCase().includes(q)) &&
    (!v || (v === 'none' ? !i.judge : i.judge === v))); };
const isPicked = i => changes.has(i.id) ? changes.get(i.id) : i.picked;
function drawTabs() {
  $('tabs').innerHTML = groups.map(g => `<button class="tab ${g.name === current ? 'on' : ''}" data-g="${g.name}">` +
    `${g.name.replace('_', ' ')} (${g.picked}/${g.found})</button>`).join('');
}
function draw() {
  const rows = matching();
  $('list').innerHTML = rows.slice(0, shown).map(i => `<label class="row"><input type="checkbox" data-id="${i.id}" ` +
    `${isPicked(i) ? 'checked' : ''} ${i.pushed ? 'disabled' : ''}><div><span class="w">${esc(i.text)}</span> ` +
    `<span class="meta">${i.times}x &middot; ${esc(i.books.slice(0, 3).join(', '))}${i.books.length > 3 ? ' +' + (i.books.length - 3) : ''}` +
    `</span> ${i.judge ? `<span class="tag">Codex: ${i.judge}${i.reason ? ' - ' + esc(i.reason) : ''}</span> ` : ''}${i.pushed ? '<span class="tag">pushed</span>' : i.status === 'done' ? '<span class="tag">written</span>' : ''}` +
    `<p class="ex">${mark(i.example)}</p></div></label>`).join('');
  $('more').hidden = rows.length <= shown;
  $('more').textContent = `Show more (${rows.length - shown} left)`;
}
async function load(name) {
  current = name; shown = PAGE_SIZE;
  items = await (await fetch('/api/items?group=' + encodeURIComponent(name))).json();
  drawTabs(); draw();
}
async function loadGroups() { groups = await (await fetch('/api/groups')).json(); drawTabs(); }
$('tabs').onclick = e => { if (e.target.dataset.g) load(e.target.dataset.g); };
$('verdict').onchange = () => { shown = PAGE_SIZE; draw(); };
$('q').oninput = () => { shown = PAGE_SIZE; draw(); };
$('more').onclick = () => { shown += PAGE_SIZE; draw(); };
$('list').onchange = e => { const id = +e.target.dataset.id; const item = items.find(i => i.id === id);
  const value = e.target.checked ? 1 : 0; if (value === item.picked) changes.delete(id); else changes.set(id, value); };
function setAll(value) { matching().filter(i => !i.pushed).forEach(i => { if (value === i.picked) changes.delete(i.id);
  else changes.set(i.id, value); }); draw(); }
$('all').onclick = () => setAll(1); $('none').onclick = () => setAll(0);
$('save').onclick = async () => {
  const body = {picked: [...changes].filter(c => c[1] === 1).map(c => c[0]),
                unpicked: [...changes].filter(c => c[1] === 0).map(c => c[0])};
  const reply = await fetch('/api/picks', {method: 'POST', headers: {'Content-Type': 'application/json'},
                                           body: JSON.stringify(body)});
  if (!reply.ok) { $('msg').textContent = 'Save failed'; return; }
  const saved = (await reply.json()).changed; changes.clear();
  $('msg').textContent = `Saved (${saved} changed)`; await loadGroups(); await load(current);
};
window.onbeforeunload = () => changes.size ? 'Unsaved ticks' : undefined;
loadGroups().then(() => groups.length ? load(groups[0].name) : ($('list').textContent = 'No book words yet.'));
</script></body></html>"""


def make_handler(db_path: Path):
    """A handler that opens its own database connection per request (sqlite connections stay in one thread)."""

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):  # quiet
            pass

        def _local_host(self) -> bool:  # refuses a request that came through another name (DNS rebinding)
            return self.headers.get("Host", "").split(":")[0] in ("127.0.0.1", "localhost")

        def _send(self, status: int, body: bytes, content_type: str) -> None:
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _json(self, data, status: int = 200) -> None:
            self._send(status, json.dumps(data).encode(), "application/json")

        def do_GET(self):
            from pipeline import collection

            if not self._local_host():
                return self._send(403, b"forbidden", "text/plain")
            url = urlparse(self.path)
            if url.path == "/":
                return self._send(200, PAGE.encode(), "text/html; charset=utf-8")
            db = collection.connect(db_path)
            try:
                if url.path == "/api/groups":
                    counts = group_counts(db)
                    return self._json([{"name": g, "found": counts[g]["found"], "picked": counts[g]["picked"]}
                                       for g in GROUPS if g in counts])
                if url.path == "/api/items":
                    return self._json(items_of_group(db, parse_qs(url.query).get("group", [""])[0]))
            finally:
                db.close()
            self._send(404, b"not found", "text/plain")

        def do_POST(self):
            from pipeline import collection

            if not self._local_host() or self.path != "/api/picks" \
                    or self.headers.get("Content-Type", "").split(";")[0] != "application/json":
                return self._send(403, b"forbidden", "text/plain")
            try:
                body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
                picked, unpicked = [int(i) for i in body["picked"]], [int(i) for i in body["unpicked"]]
            except (ValueError, KeyError, TypeError):
                return self._json({"error": "bad request"}, 400)
            db = collection.connect(db_path)
            try:
                self._json({"changed": save_picks(db, picked, unpicked)})
            finally:
                db.close()

    return Handler


def make_server(db_path: Path, port: int = 8765) -> ThreadingHTTPServer:
    """The review server, bound to 127.0.0.1 only."""
    return ThreadingHTTPServer(("127.0.0.1", port), make_handler(db_path))


def review(db_path: Path, port: int = 8765, open_browser: bool = True) -> None:
    server = make_server(db_path, port)
    url = f"http://127.0.0.1:{server.server_address[1]}/"
    print(f"Review page: {url}  (Ctrl+C to stop)")
    if open_browser:
        threading.Timer(0.5, webbrowser.open, args=(url,)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
