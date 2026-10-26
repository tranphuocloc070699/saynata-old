---
id: TASK-83.17
title: 'Admin: run prefill now from the Pending queue (source picker and cap)'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-25 07:42'
updated_date: '2026-10-25 07:46'
labels:
  - admin
  - prefill
dependencies: []
parent_task_id: TASK-83
ordinal: 127000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Pending queue footer in the admin CMS gets a source picker (all pending sources or one), a cap field in USD (default PREFILL_MAX_USD_PER_RUN, at most 10) and an icon-only play button that calls POST /api/admin/prefill/run. While a run is going the footer shows it and refreshes; after it, the last run's result. Backend endpoint already exists (TASK-83.12).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Play button starts a run with the picked source and cap
- [x] #2 Picker lists only sources with pending items, with counts
- [x] #3 Cap outside 0-10 is refused before the call
- [x] #4 While running the button is busy and the footer refreshes; after, the last run result shows
- [x] #5 Admin test covers the run call
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. RunNow in PendingQueue footer: picker, cap, play
2. Poll overview + rows while running
3. Tests, docs
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Built in PendingQueue.tsx (RunNow). No backend change: POST /api/admin/prefill/run already existed. Tests: admin pendingQueue.test.tsx (11 pass).
<!-- SECTION:NOTES:END -->
