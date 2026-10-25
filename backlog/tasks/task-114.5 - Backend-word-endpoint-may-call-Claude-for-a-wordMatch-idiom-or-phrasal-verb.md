---
id: TASK-114.5
title: 'Backend: word endpoint may call Claude for a wordMatch (idiom or phrasal verb)'
status: In Progress
assignee: []
created_date: '2026-10-25 09:32'
updated_date: '2026-10-25 11:59'
labels: []
dependencies:
  - TASK-114.1
documentation:
  - backlog/docs/features/doc-5 - Word-lookup.md
parent_task_id: TASK-114
ordinal: 136000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-114.1 returns wordMatch for a single non-English word, phrasal verb or idiom. GET /api/words/{phrase} answers a 2-6 word phrase only from the cache (404 not_cached on a miss), and a one-word match missing from the word list can fail too, so the clients would often fall back to the sentence result. Developer decision (2026-10-25): the word endpoint may call Claude for a wordMatch.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A wordMatch (one word, phrasal verb or idiom) that is not bundled or cached is described by Claude through ClaudeGate and saved in the word cache; the next request is free
- [ ] #2 A plain phrase lookup without the wordMatch signal keeps the old rule (cache only, 404 not_cached), so typing random phrases cannot spend Claude calls; the signal is decided on the backend (for example the wordMatch alias row from sentence_source_alias), not a client flag
- [ ] #3 Guests, limits and budget errors behave as in doc-17 (401 sign_in_required, 429, 503); cachedOnly never calls Claude
- [ ] #4 Tests with the fake key; doc-5, doc-17 updated; check_docs.py passes
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR #215 merged into feature/local (stacked on #214, also merged). Alias check: SentenceSourceAliasRepository.existsWordMatch(wordMatch, promptVersion); WordService.lookUp lets an alias word_match skip the cache-only phrase rule and the word-list check, then normal path (cache, ClaudeGate.beforeNewCall, simple-word check, save, media). Not Done: waits for developer test; real-Claude check of 'bỏ cuộc' -> 'give up' still open.
<!-- SECTION:NOTES:END -->
