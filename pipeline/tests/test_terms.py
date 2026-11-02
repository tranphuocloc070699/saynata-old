"""TASK-119.2: terms from Wikidata. No network: a fake Wikidata answers from dicts."""

from pathlib import Path

from pipeline import terms
from pipeline.terms import alias_key, build, collisions, exact_match, parse_entity, rule_aliases, write

NUXT = {
    "id": "Q55697000",
    "labels": {"en": {"value": "Nuxt"}},
    "descriptions": {"en": {"value": "free and open source JavaScript framework"}},
    "aliases": {"en": [{"value": "Nuxt.js"}, {"value": "NuxtJS"}]},
    "claims": {"P856": [
        {"rank": "deprecated", "mainsnak": {"datavalue": {"value": "https://old.nuxtjs.org"}}},
        {"rank": "normal", "mainsnak": {"datavalue": {"value": "https://nuxtjs.org"}}},
        {"rank": "preferred", "mainsnak": {"datavalue": {"value": "https://nuxt.com"}}},
    ]},
    "sitelinks": {"enwiki": {"title": "Nuxt.js"}, "dewiki": {"title": "Nuxt.js"}},
}
SWIFT = {
    "id": "Q17118377",
    "labels": {"en": {"value": "Swift"}},
    "descriptions": {"en": {"value": "general-purpose programming language by Apple"}},
    "claims": {},
    "sitelinks": {"enwiki": {"title": "Swift (programming language)"}},
}


class FakeWikidata:
    def __init__(self, searches: dict, entities: dict):
        self.searches, self._entities = searches, entities

    def search(self, name):
        return self.searches.get(name, {"search": []})

    def entities(self, qids):
        return {q: self._entities[q] for q in qids if q in self._entities}


def test_alias_key_matches_the_backend_rule():
    for text in ["Nuxt.js", "NuxtJS", "nuxt js", "nuxt-js", "nuxt_js", "nuxtjs"]:
        assert alias_key(text) == "nuxtjs"
    assert alias_key("Freud's") == "freuds"


def test_rule_aliases_drop_js_but_never_make_short_keys():
    assert rule_aliases("nuxtjs") == ["nuxt"]
    assert rule_aliases("vuejs") == ["vue"]
    assert rule_aliases("ajs") == []
    assert rule_aliases("react") == []


def test_a_programming_language_also_gets_the_lang_alias():
    assert rule_aliases("go", "programming language designed at Google") == ["golang"]
    assert rule_aliases("golang", "programming language") == []
    assert rule_aliases("go", "board game") == []


def test_parse_entity_takes_the_preferred_site_the_wikipedia_link_and_all_aliases():
    row = parse_entity(NUXT)
    assert row.name == "Nuxt"
    assert row.field == "free and open source JavaScript framework"
    assert row.official_url == "https://nuxt.com"
    assert row.wikipedia_url == "https://en.wikipedia.org/wiki/Nuxt.js"
    assert row.popularity == 2
    assert row.aliases == {"nuxt": "wikidata", "nuxtjs": "wikidata"}


def test_parse_entity_without_site_or_label():
    row = parse_entity(SWIFT)
    assert row.aliases == {"swift": "wikidata", "swiftlang": "rule"}
    assert row.official_url == ""
    assert row.wikipedia_url == "https://en.wikipedia.org/wiki/Swift_%28programming_language%29"
    assert parse_entity({"id": "Q1", "labels": {}}) is None


def test_exact_match_only():
    search = {"search": [
        {"id": "Q9", "label": "Node", "aliases": []},
        {"id": "Q756100", "label": "Node.js", "match": {"text": "Node.js"}},
    ]}
    assert exact_match(search, "nodejs") == "Q756100"
    assert exact_match(search, "node.js framework") is None


def test_a_hint_picks_the_item_whose_description_has_it():
    search = {"search": [
        {"id": "Q1", "label": "React", "description": "American band"},
        {"id": "Q19399674", "label": "React", "description": "JavaScript library for building user interfaces"},
    ]}
    assert exact_match(search, "React") == "Q1"
    assert exact_match(search, "React", "javascript") == "Q19399674"
    assert exact_match(search, "React", "python") is None


def test_build_keeps_seed_order_skips_duplicates_and_reports_misses():
    fake = FakeWikidata(
        {"Nuxt": {"search": [{"id": "Q1", "label": "Nuxt", "description": "a town"},
                             {"id": "Q55697000", "label": "Nuxt", "description": "JavaScript framework"}]},
         "nuxtjs": {"search": [{"id": "Q55697000", "label": "Nuxt", "aliases": ["NuxtJS"]}]}},
        {"Q55697000": NUXT, "Q17118377": SWIFT},
    )
    rows, not_found = build(["Nuxt | framework", "nuxtjs", "Q17118377", "asdfjs", "Q404"], fake)
    assert [r.name for r in rows] == ["Nuxt", "Swift"]
    assert not_found == ["asdfjs", "Q404"]


def test_collisions_and_written_files(tmp_path: Path):
    rows = [parse_entity(NUXT), parse_entity(SWIFT)]
    other = parse_entity({**SWIFT, "id": "Q2", "labels": {"en": {"value": "SWIFT"}}, "sitelinks": {}})
    rows.append(other)
    words, shared = collisions(rows, {"swift", "fast"})
    assert words == {"swift": ["Swift", "SWIFT"]}
    assert shared == {"swift": ["Swift", "SWIFT"], "swiftlang": ["Swift", "SWIFT"]}

    report = write(rows, ["asdfjs"], {"swift"}, tmp_path)
    terms_tsv = (tmp_path / "terms.tsv").read_text().splitlines()
    assert terms_tsv[0].split("\t")[:2] == ["wikidata_id", "name"]
    assert terms_tsv[1].split("\t") == ["Q55697000", "Nuxt", "free and open source JavaScript framework", "",
                                        "https://nuxt.com", "https://en.wikipedia.org/wiki/Nuxt.js", "2"]
    aliases = (tmp_path / "term_aliases.tsv").read_text().splitlines()
    assert "nuxtjs\tQ55697000\twikidata" in aliases
    assert "asdfjs" in report and "- swift: Swift, SWIFT" in report


def test_the_cache_answers_a_second_time_without_a_request(tmp_path: Path):
    class CountingClient:
        calls = 0

        def get(self, url, params):
            CountingClient.calls += 1

            class Response:
                status_code = 200
                headers = {}

                def raise_for_status(self):
                    pass

                def json(self):
                    return {"search": [{"id": "Q55697000", "label": "Nuxt"}]}

            return Response()

    wikidata = terms.Wikidata(tmp_path, pause=0, client=CountingClient())
    assert wikidata.search("Nuxt")["search"][0]["id"] == "Q55697000"
    assert wikidata.search("nuxt")["search"][0]["id"] == "Q55697000"
    assert CountingClient.calls == 1
