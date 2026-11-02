"""Terms from Wikidata (TASK-119.2, no LLM). Run from saynata-old/pipeline:

    uv run python -m pipeline.terms                 # every seed
    uv run python -m pipeline.terms --limit 20      # the first 20 seeds

Input : ../exports/terms/seeds.txt   one name ("Node.js") or Q-id per line, "#" starts a comment. A name that means
        several things takes a hint after "|" that the Wikidata description must contain: "React | JavaScript".
Output: ../exports/terms/terms.tsv         wikidata_id, name, field, simple_definition, official_url, wikipedia_url, popularity
        ../exports/terms/term_aliases.tsv  alias_key, wikidata_id, source
        ../exports/terms/report.md         counts, seeds not found, aliases that are English words or shared
Cache : ../exports/terms/.cache/       one JSON file per Wikidata answer, so a second run asks nothing again

A name is kept only when Wikidata's search finds an item whose label or alias is exactly that name (case and the
characters of alias_key ignored). The official site is Wikidata's P856, never written by an LLM.
Load the files with exports/terms/import_terms.sh.
"""

from __future__ import annotations

import argparse
import json
import re
import time
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import quote

import httpx

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "exports" / "terms"
WORDS = ROOT / "backend" / "src" / "main" / "resources" / "words"
API = "https://www.wikidata.org/w/api.php"
# Wikimedia asks every client for a User-Agent that says who it is (https://meta.wikimedia.org/wiki/User-Agent_policy).
USER_AGENT = "SaynataTerms/0.1 (https://github.com/tranphuocloc070699/saynata-old)"
QID = re.compile(r"^Q\d+$")
DROPPED = re.compile(r"[\s._'’-]+")
MAX_FIELD = 250


def alias_key(text: str) -> str:
    """Same rule as the backend's TermKeys.key: lower case, without dots, dashes, underscores, apostrophes, spaces."""
    return DROPPED.sub("", text.lower())


@dataclass
class TermRow:
    wikidata_id: str
    name: str
    field: str
    official_url: str
    wikipedia_url: str
    popularity: int
    aliases: dict[str, str] = field(default_factory=dict)  # alias_key -> source


def rule_aliases(key: str) -> list[str]:
    """Extra keys people type: "nuxtjs" -> "nuxt". Never shorter than 3 characters."""
    extra = []
    if key.endswith("js") and len(key) >= 5:
        extra.append(key[:-2])
    return extra


def _best_claim(claims: list[dict]) -> str:
    """The value of the preferred claim, else the first normal one, else empty. Deprecated claims are skipped."""
    ranked = [c for c in claims if c.get("rank") != "deprecated"]
    ranked.sort(key=lambda c: c.get("rank") != "preferred")
    for claim in ranked:
        value = claim.get("mainsnak", {}).get("datavalue", {}).get("value")
        if isinstance(value, str) and value.startswith(("https://", "http://")):
            return value
    return ""


def parse_entity(entity: dict) -> TermRow | None:
    """One Wikidata item -> a term with its Wikidata aliases. None when it has no English label."""
    label = entity.get("labels", {}).get("en", {}).get("value")
    if not label:
        return None
    description = entity.get("descriptions", {}).get("en", {}).get("value", "")[:MAX_FIELD]
    sitelinks = entity.get("sitelinks", {})
    enwiki = sitelinks.get("enwiki", {}).get("title")
    row = TermRow(
        wikidata_id=entity["id"],
        name=label,
        field=description,
        official_url=_best_claim(entity.get("claims", {}).get("P856", [])),
        wikipedia_url=f"https://en.wikipedia.org/wiki/{quote(enwiki.replace(' ', '_'))}" if enwiki else "",
        popularity=len(sitelinks),
    )
    names = [label] + [a["value"] for a in entity.get("aliases", {}).get("en", [])]
    for name in names:
        key = alias_key(name)
        if key:
            row.aliases.setdefault(key, "wikidata")
    for key in list(row.aliases):
        for extra in rule_aliases(key):
            row.aliases.setdefault(extra, "rule")
    return row


def exact_match(search: dict, name: str, hint: str = "") -> str | None:
    """The Q-id of the first search hit whose label or alias is exactly the name (alias_key compared) and whose
    description contains the hint (any case), when one is given."""
    wanted = alias_key(name)
    for hit in search.get("search", []):
        if hint and hint.lower() not in hit.get("description", "").lower():
            continue
        texts = [hit.get("label", ""), hit.get("match", {}).get("text", "")] + hit.get("aliases", [])
        if any(alias_key(text) == wanted for text in texts):
            return hit["id"]
    return None


def read_seeds(path: Path) -> list[str]:
    seeds = []
    for line in path.read_text(encoding="utf-8").splitlines():
        text = line.split("#", 1)[0].strip()
        if text and text not in seeds:
            seeds.append(text)
    return seeds


def read_words(path: Path) -> set[str]:
    return {line.split("\t")[0].strip().lower() for line in path.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.startswith("#")}


class Wikidata:
    """The two API calls, with a JSON file cache and a pause between real requests (polite: one at a time)."""

    def __init__(self, cache_dir: Path, pause: float = 1.0, client: httpx.Client | None = None):
        self.cache_dir = cache_dir
        self.pause = pause
        self.client = client or httpx.Client(headers={"User-Agent": USER_AGENT}, timeout=30)

    def _get(self, cache_name: str, params: dict) -> dict:
        path = self.cache_dir / f"{cache_name}.json"
        if path.exists():
            return json.loads(path.read_text(encoding="utf-8"))
        for attempt in range(4):
            response = self.client.get(API, params={**params, "format": "json"})
            if response.status_code == 429 or response.status_code >= 500:
                time.sleep(int(response.headers.get("Retry-After", 5 * (attempt + 1))))
                continue
            response.raise_for_status()
            break
        else:
            response.raise_for_status()
        data = response.json()
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data), encoding="utf-8")
        time.sleep(self.pause)
        return data

    def search(self, name: str) -> dict:
        return self._get(f"search-{alias_key(name) or 'x'}",
                         {"action": "wbsearchentities", "search": name, "language": "en", "type": "item", "limit": 7})

    def entities(self, qids: list[str]) -> dict[str, dict]:
        result: dict[str, dict] = {}
        for start in range(0, len(qids), 50):  # the API takes at most 50 ids per call
            batch = qids[start:start + 50]
            data = self._get(f"entities-{'-'.join(batch)}"[:200],
                             {"action": "wbgetentities", "ids": "|".join(batch),
                              "props": "labels|descriptions|aliases|claims|sitelinks", "languages": "en"})
            result.update({qid: e for qid, e in data.get("entities", {}).items() if "missing" not in e})
        return result


def build(seeds: list[str], wikidata: Wikidata) -> tuple[list[TermRow], list[str]]:
    """Seeds -> terms (in seed order, no duplicates) and the seeds that found nothing."""
    qids: list[str] = []
    not_found: list[str] = []
    for seed in seeds:
        name, _, hint = (part.strip() for part in seed.partition("|"))
        qid = name if QID.match(name) else exact_match(wikidata.search(name), name, hint)
        if qid is None:
            not_found.append(seed)
        elif qid not in qids:
            qids.append(qid)
    entities = wikidata.entities(qids)
    rows = []
    for qid in qids:
        row = parse_entity(entities[qid]) if qid in entities else None
        if row is None:
            not_found.append(qid)
        else:
            rows.append(row)
    return rows, not_found


def collisions(rows: list[TermRow], english: set[str]) -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    """(aliases that are English words -> terms, aliases shared by several terms -> terms)."""
    by_key: dict[str, list[str]] = defaultdict(list)
    for row in rows:
        for key in row.aliases:
            by_key[key].append(row.name)
    words = {key: names for key, names in by_key.items() if key in english}
    shared = {key: names for key, names in by_key.items() if len(names) > 1}
    return words, shared


def write(rows: list[TermRow], not_found: list[str], english: set[str], out: Path) -> str:
    out.mkdir(parents=True, exist_ok=True)

    def clean(text: str) -> str:
        return text.replace("\t", " ").replace("\n", " ").replace('"', "'")

    with (out / "terms.tsv").open("w", encoding="utf-8") as f:
        f.write("wikidata_id\tname\tfield\tsimple_definition\tofficial_url\twikipedia_url\tpopularity\n")
        for r in rows:
            f.write(f"{r.wikidata_id}\t{clean(r.name)}\t{clean(r.field)}\t\t{r.official_url}\t{r.wikipedia_url}\t{r.popularity}\n")
    with (out / "term_aliases.tsv").open("w", encoding="utf-8") as f:
        f.write("alias_key\twikidata_id\tsource\n")
        for r in rows:
            for key, source in sorted(r.aliases.items()):
                f.write(f"{key}\t{r.wikidata_id}\t{source}\n")

    words, shared = collisions(rows, english)
    alias_count = sum(len(r.aliases) for r in rows)
    lines = [
        "# Terms report", "",
        f"{len(rows):,} terms, {alias_count:,} aliases, {sum(1 for r in rows if r.official_url):,} with an official site.", "",
        f"## Seeds not found ({len(not_found)})", "", ", ".join(not_found) or "none", "",
        f"## Aliases that are English words ({len(words)})", "",
        "Shown below the English senses, never in place of them.", "",
        *[f"- {key}: {', '.join(names)}" for key, names in sorted(words.items())], "",
        f"## Aliases shared by several terms ({len(shared)})", "",
        "The reply shows at most 3, most popular first.", "",
        *[f"- {key}: {', '.join(names)}" for key, names in sorted(shared.items())], "",
    ]
    report = "\n".join(lines)
    (out / "report.md").write_text(report, encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Build terms.tsv and term_aliases.tsv from Wikidata (no LLM)")
    parser.add_argument("--limit", type=int, default=0, help="only the first N seeds")
    parser.add_argument("--seeds", type=Path, default=OUT / "seeds.txt")
    args = parser.parse_args()
    seeds = read_seeds(args.seeds)
    if args.limit:
        seeds = seeds[:args.limit]
    rows, not_found = build(seeds, Wikidata(OUT / ".cache"))
    english = read_words(WORDS / "scowl-70.txt") | read_words(WORDS / "ngsl.txt")
    print(write(rows, not_found, english, OUT))


if __name__ == "__main__":
    main()
