"""Word forms for every existing word (no LLM). Run from saynata-old/pipeline:

    uv run python ../exports/word-forms/build_word_forms.py

Input : ../existing_words.txt (lemmas, forms and phrases from the VPS DB)
Output: word_forms.tsv   form -> lemma, with a label (past tense, plural, ...)
        form_entries.tsv existing words that are a form of another existing word (merge candidates)
        report.md        counts and samples

Forms come from lemminflect's dictionary only (getAllInflections without a part of speech), so no guessed forms.
A form is kept only when it is a real word: in scowl-70 or in zipf-en (backend word lists).
"""

from collections import Counter, defaultdict
from pathlib import Path

from lemminflect import getAllInflections, getAllLemmas

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
WORDS = ROOT / "backend/src/main/resources/words"

TAGS = {  # tag -> (group, label); first tag of a group wins for a form
    "VBD": ("VERB", "past tense"), "VBN": ("VERB", "past participle"), "VBG": ("VERB", "-ing form"),
    "VBZ": ("VERB", "third person"), "NNS": ("NOUN", "plural"),
    "JJR": ("ADJ", "comparative"), "JJS": ("ADJ", "superlative"),
    "RBR": ("ADV", "comparative"), "RBS": ("ADV", "superlative"),
}
ORDER = list(TAGS)


def read_list(path: Path) -> list[str]:
    return [line.split("\t")[0].strip().lower() for line in path.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.startswith("#")]


def label(tags: set[str]) -> str:
    groups = {TAGS[t][0] for t in tags}
    if len(groups) > 1:
        return "form"  # "runs": plural noun and third person verb
    return TAGS[min(tags, key=ORDER.index)][1]


def forms_of(lemma: str) -> dict[str, set[str]]:
    """{form: {tags}} from lemminflect's dictionary, without the lemma itself."""
    result: dict[str, set[str]] = defaultdict(set)
    for tag, forms in getAllInflections(lemma).items():
        if tag in TAGS:
            for form in forms:
                form = form.lower()
                if form != lemma:
                    result[form].add(tag)
    return result


def main() -> None:
    existing = read_list(ROOT / "existing_words.txt")
    known = set(existing)
    real = set(read_list(WORDS / "scowl-70.txt")) | set(read_list(WORDS / "zipf-en.tsv"))
    zipf = {l.split("\t")[0]: float(l.split("\t")[1])
            for l in (WORDS / "zipf-en.tsv").read_text(encoding="utf-8").splitlines() if "\t" in l}
    words = [w for w in existing if " " not in w]
    phrases = [p for p in existing if " " in p]

    rows: dict[tuple[str, str], tuple[str, str]] = {}  # (form, lemma) -> (type, kind)
    dropped = 0
    for lemma in words:
        for form, tags in forms_of(lemma).items():
            if form in real:
                rows[(form, lemma)] = (label(tags), "word")
            else:
                dropped += 1

    # Phrases: inflect the first word when it is a verb ("give up" -> "gave up").
    for phrase in phrases:
        head, rest = phrase.split(" ", 1)
        for form, tags in forms_of(head).items():
            verb_tags = {t for t in tags if TAGS[t][0] == "VERB"}
            if verb_tags and form in real:
                rows[(f"{form} {rest}", phrase)] = (label(verb_tags), "phrase")

    with (HERE / "word_forms.tsv").open("w", encoding="utf-8") as out:
        out.write("form\tlemma\tform_type\tkind\n")
        for (form, lemma), (ftype, kind) in sorted(rows.items()):
            out.write(f"{form}\t{lemma}\t{ftype}\t{kind}\n")

    # Existing words that are a form of another existing word.
    entries = []
    for word in words:
        lemmas = {l.lower() for ls in getAllLemmas(word).values() for l in ls}
        others = sorted(l for l in lemmas if l != word and l in known)
        if others:
            status = "own meaning too" if word in lemmas else "pure form"
            entries.append((word, ",".join(others), status, zipf.get(word, 0.0)))
    with (HERE / "form_entries.tsv").open("w", encoding="utf-8") as out:
        out.write("word\tlemma\tstatus\tzipf\n")
        for word, lemmas, status, z in sorted(entries):
            out.write(f"{word}\t{lemmas}\t{status}\t{z:.2f}\n")

    kinds = Counter(kind for _, kind in rows.values())
    types = Counter(t for t, _ in rows.values())
    new_forms = {f for f, _ in rows if f not in known}
    statuses = Counter(e[2] for e in entries)
    pure = sorted((e for e in entries if e[2] == "pure form"), key=lambda e: -e[3])
    own = sorted((e for e in entries if e[2] == "own meaning too"), key=lambda e: -e[3])

    def sample(items, n=15):
        return ", ".join(f"{e[0]} → {e[1]}" for e in items[:n])

    lines = [
        "# Word forms report", "",
        f"Input: {len(existing):,} existing entries ({len(words):,} single words, {len(phrases):,} phrases).", "",
        "## word_forms.tsv", "",
        "| | Rows |", "|---|---|",
        f"| all (form, lemma) pairs | {len(rows):,} |",
        f"| from single words | {kinds['word']:,} |",
        f"| from phrases (first word inflected) | {kinds['phrase']:,} |",
        f"| distinct forms not yet in the DB | {len(new_forms):,} |",
        f"| dropped: not in scowl-70 / zipf | {dropped:,} |", "",
        "| form_type | Rows |", "|---|---|",
        *[f"| {t} | {n:,} |" for t, n in types.most_common()], "",
        "## form_entries.tsv (existing words that are a form of another existing word)", "",
        "| status | Words | Meaning |", "|---|---|---|",
        f"| pure form | {statuses['pure form']:,} | only a form (e.g. contaminated): merge into the lemma |",
        f"| own meaning too | {statuses['own meaning too']:,} | also a word of its own (e.g. glasses): review |", "",
        f"Most common pure forms: {sample(pure)}", "",
        f"Most common 'own meaning too': {sample(own)}", "",
    ]
    (HERE / "report.md").write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
