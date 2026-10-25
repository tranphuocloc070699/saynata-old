---
id: TASK-114.1
title: >-
  Backend: non-English input returns the English version, detected language and
  word match
status: In Progress
assignee: []
created_date: '2026-10-25 09:23'
updated_date: '2026-10-25 11:59'
labels: []
dependencies: []
documentation:
  - backlog/docs/features/doc-4 - Sentence-translation.md
  - backlog/docs/features/doc-5 - Word-lookup.md
  - backlog/docs/doc-1 - Vision-and-spec.md
parent_task_id: TASK-114
ordinal: 132000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Backend part of TASK-114. Today any non-English text gets 422 (TASK-21). The sentence endpoints must instead detect the language, return the natural English version first, and for a single non-English word, phrasal verb or idiom name the English headword so the clients can open the existing word card ('buồn' -> 'sad'). Code and gibberish keep the 422. Clients (TASK-114.2-4) wait for the field names fixed here.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Prompt bumped to v12 (application.properties app.claude.sentence-prompt-version, PromptVersions.sentence in CacheKeys.swift and a test that they match); Claude returns sourceLang (ISO code, or none for code/gibberish), english (natural English version, empty when the text is English), wordMatch (one English headword/phrasal verb/idiom for a single non-English item, else empty), then summary of the English version
- [ ] #2 Non-English sentence: response has english (first field) and sourceLang, then meaning, words, better, translation; nothing changes for English input (new fields null/absent)
- [ ] #3 Cached by the English version: two different Vietnamese sentences with the same English version share one English part; the typed text is still the 'text' of the answer; the language line is built from the typed text
- [ ] #4 Single non-English word/phrasal verb/idiom: response has wordMatch; no good single match: wordMatch empty and the sentence result is returned
- [ ] #5 Code and gibberish still give 422 with the current message; nothing cached; streaming endpoint behaves the same (english and sourceLang arrive in done)
- [ ] #6 Tests with the fake Claude key: Vietnamese sentence, another language (Japanese), single word with match, single word without match, code/gibberish 422, cache sharing; old tests updated
- [ ] #7 doc-1 (line 116 rule), doc-4 (Not English rows), doc-5 and doc-24 updated; check_docs.py passes
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR https://github.com/tranphuocloc070699/saynata/pull/214. Explanation JSON order: english, sourceLang, wordMatch, meaning, words, better, betterWhy, translation. english/sourceLang/wordMatch are OMITTED (not null) for English input, so clients decode them as optional. sourceLang = lowercase ISO code (zh-CN -> zh). wordMatch = lowercase valid word path or absent. translation: target en = the English version; target = typed language = typed text; else line from typed text. Streaming: meaning events carry the English-version summary, done carries the new fields. Flyway V33 sentence_source_alias. Open: word endpoint answers a 2-6 word wordMatch only from cache (404 not_cached on miss) -> clients fall back to the sentence result. Prompt v12 not tested with real Claude.

PR #214 merged into feature/local. Waits for developer test.
<!-- SECTION:NOTES:END -->
