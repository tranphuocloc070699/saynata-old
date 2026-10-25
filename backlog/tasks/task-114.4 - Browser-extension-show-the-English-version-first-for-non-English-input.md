---
id: TASK-114.4
title: 'Browser extension: show the English version first for non-English input'
status: To Do
assignee: []
created_date: '2026-10-25 09:23'
updated_date: '2026-10-25 11:57'
labels: []
dependencies:
  - TASK-114.1
  - TASK-114.5
parent_task_id: TASK-114
ordinal: 135000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Browser extension part of TASK-114. Developer decision 2026-10-25: no new UI. Keep the current cards. When explanation.english is present it takes the headline slot (where the typed sentence shows today); the simple summary and the collapsed target-language row follow as before. No 'From <language>' note. explanation.wordMatch opens the normal word card (backend allows the Claude call, TASK-114.5); if that lookup fails or finds nothing, show the sentence result. English input is unchanged. Decode english/sourceLang/wordMatch as optional. Branch from 114/task-114-5, PR into feature/local.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 english takes the headline slot of the card when present; wordMatch shows the word card, with fallback to the sentence result
- [ ] #2 Vitest tests: Vietnamese, Japanese, English; doc-19 updated; check_docs.py passes
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
