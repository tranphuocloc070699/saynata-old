---
id: TASK-102.3
title: >-
  Web homepage: two columns on a wide screen (composer left, result right), max
  width 1224px
status: To Do
assignee: []
created_date: '2026-10-24 16:58'
updated_date: '2026-11-09 09:16'
labels:
  - web
dependencies: []
parent_task_id: TASK-102
ordinal: 123000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
On a PC the result pushed the page below the fold. With a result, a wide screen (lg) shows the composer and chips on the left (sticky) and the result on the right; before a result the composer stays alone in the middle (680px). Header, main and footer widths go from 680px to 1224px. Phones keep one column.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 At lg and up, a word or sentence result sits right of a sticky composer
- [x] #2 Idle page keeps the composer centred at 680px
- [x] #3 Phone width keeps one column with no horizontal scroll
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Merged into feature/local in PR #188 (2f52ac1). The developer tested it on 2026-10-25. Goes to main with the next release.
<!-- SECTION:NOTES:END -->
