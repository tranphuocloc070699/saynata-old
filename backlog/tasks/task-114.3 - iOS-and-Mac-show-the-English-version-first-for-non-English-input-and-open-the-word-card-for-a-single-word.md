---
id: TASK-114.3
title: >-
  iOS and Mac: show the English version first for non-English input, and open
  the word card for a single word
status: To Do
assignee: []
created_date: '2026-10-25 09:23'
updated_date: '2026-10-25 11:57'
labels: []
dependencies:
  - TASK-114.1
  - TASK-114.5
parent_task_id: TASK-114
ordinal: 134000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
iOS and Mac part of TASK-114. Today a single non-English token goes to the word path, gets empty senses (notAnEnglishWord) and falls back to the sentence path; wordMatch replaces that dead end. Developer decision 2026-10-25: no new UI. Keep the current cards. When explanation.english is present it takes the headline slot (where the typed sentence shows today); the simple summary and the collapsed target-language row follow as before. No 'From <language>' note. explanation.wordMatch opens the normal word card (backend allows the Claude call, TASK-114.5); if that lookup fails or finds nothing, show the sentence result. English input is unchanged. Decode english/sourceLang/wordMatch as optional. Branch from 114/task-114-5, PR into feature/local.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Explanation decodes the optional fields; old phone-cache answers still decode
- [ ] #2 english takes the headline slot; summary and language row unchanged
- [ ] #3 wordMatch opens the word card through the existing flow; failure or empty falls back to the sentence result
- [ ] #4 History, Liked, Quick explain / Explain copied text and the Mac panel handle it (they say Not English today)
- [ ] #5 Swift Testing decode and store tests; doc-4, doc-5, doc-20, doc-21, doc-22 updated; check_docs.py passes
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Developer decision 2026-10-25: NO new UI. Keep the current sentence card and word card exactly as they are. The headline slot (where the typed sentence shows today) shows the English version (explanation.english) when present; the rest is unchanged: simple summary, then the target-language row. No 'From <language>' note or chip, so the mockup step is not needed. wordMatch opens the normal word card. English input unchanged.
<!-- SECTION:NOTES:END -->
