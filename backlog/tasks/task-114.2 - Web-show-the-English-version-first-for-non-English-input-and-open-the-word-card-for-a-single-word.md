---
id: TASK-114.2
title: >-
  Web: show the English version first for non-English input, and open the word
  card for a single word
status: To Do
assignee: []
created_date: '2026-10-25 09:23'
updated_date: '2026-10-25 12:39'
labels: []
dependencies:
  - TASK-114.1
  - TASK-114.5
parent_task_id: TASK-114
ordinal: 133000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Web part of TASK-114. Developer decision 2026-10-25: no new UI. Keep the current cards. When explanation.english is present it takes the headline slot (where the typed sentence shows today); the simple summary and the collapsed target-language row follow as before. No 'From <language>' note. explanation.wordMatch opens the normal word card (backend allows the Claude call, TASK-114.5); if that lookup fails or finds nothing, show the sentence result. English input is unchanged. Decode english/sourceLang/wordMatch as optional. Branch from 114/task-114-5, PR into feature/local.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 english replaces the typed sentence in the headline when present; summary and language row unchanged
- [ ] #2 wordMatch opens the word card; failure or empty falls back to the sentence result
- [ ] #3 Vitest tests: Vietnamese, Japanese, English (unchanged), wordMatch, fallback; doc-23 updated; check_docs.py passes
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Follow-up (PR #219): a word the word API cannot answer (200 without senses, 404, 422) now goes to the sentence API (explain.ts explainWord). If that fails the word answer stays, except a 422 with code not_a_word / a_name, whose server text is shown. ApiError.code added. Tests: web explain.test.ts and api.test.ts pass (40).
<!-- SECTION:NOTES:END -->
