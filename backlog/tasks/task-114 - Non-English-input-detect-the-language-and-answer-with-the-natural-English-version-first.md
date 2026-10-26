---
id: TASK-114
title: >-
  Non-English input: detect the language and answer with the natural English
  version first
status: To Do
assignee: []
created_date: '2026-10-25 09:18'
updated_date: '2026-10-25 11:57'
labels: []
dependencies: []
documentation:
  - backlog/docs/doc-1 - Vision-and-spec.md
  - backlog/docs/features/doc-4 - Sentence-translation.md
priority: medium
ordinal: 131000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Learners type what they want to say in their own language (for example 'Hôm nay tôi buồn') because they do not know the English yet. Until now the backend answered 422 (TASK-21). Now: a non-English sentence shows the natural English version as the headline (explanation.english), then the usual simple explanation and the target-language line; a single non-English word, phrasal verb or idiom opens the normal English word card ('buồn' -> 'sad') through explanation.wordMatch; code and gibberish still get 422.

Developer decisions (2026-10-25): (1) no new UI: the current sentence card and word card stay as they are; the English version takes the headline slot where the typed sentence shows today; no 'From <language>' note. (2) The word endpoint may call Claude for a wordMatch (TASK-114.5).

State: backend done, PRs open into feature/local, not merged: #214 (TASK-114.1) and #215 (TASK-114.5, stacked on #214). Clients (114.2 web, 114.3 iOS/Mac, 114.4 extension) not started; each branches from 114/task-114-5, PR into feature/local.
JSON (see TASK-114.1 notes): explanation order english, sourceLang, wordMatch, meaning, words, better, betterWhy, translation; the first three are omitted for English input, so decode them as optional.
Before release: run a few real texts through prompt v12 (Vietnamese sentence, 'buồn', 'bỏ cuộc' -> 'give up', a Japanese sentence, gibberish); not tested with real Claude yet.
Process: commit the TASK-114 task files so worker worktrees can see them; the clients touch files with uncommitted changes in the main checkout (web Home.tsx, SentenceCard.tsx, WordCard.tsx, explain.ts).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Backend: a non-English sentence returns the natural English version as the first field, then the simple English explanation, words and target-language line; the detected source language is in the response
- [ ] #2 Code and gibberish still return 422 with the current message
- [ ] #3 Sentence prompt version is bumped in application.properties; results are cached by the English version so the same meaning is not paid twice
- [ ] #4 Tests cover Vietnamese input, another language input, and code/gibberish still rejected (backend with fake Claude key; client decode tests)
- [ ] #5 doc-1, doc-4 (Not English rows) and doc-7 are updated
- [ ] #6 A single non-English word, phrasal verb or idiom opens the English word card for its English match (e.g. buồn → sad), with a small note of the detected language; the word lookup uses the existing word flow and cache
- [ ] #7 When a single non-English item has no good single English match, it falls back to the sentence result (English version first)
- [ ] #8 Web, iOS/Mac and extension show the English version in the headline slot of the current cards (no new UI, no language note)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
