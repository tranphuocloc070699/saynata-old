---
id: TASK-115.1
title: 'Stop new Pixabay pictures: empty key, hide Pick another, decide for new words'
status: To Do
assignee: []
created_date: '2026-10-25 15:11'
labels:
  - media
  - backend
  - admin
dependencies: []
parent_task_id: TASK-115
ordinal: 140000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
New words still get Pixabay pictures from the background job, and the admin can still pick Pixabay results. This must stop first, or the Pixabay count keeps growing while the AI run is going.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 PIXABAY_API_KEY is empty on the production server and the background job claims nothing
- [ ] #2 Admin no longer shows Pick another; search and pick endpoints are not reachable from the UI
- [ ] #3 New backend words get no picture, or a capped AI picture job (decision recorded in doc-7)
- [ ] #4 doc-15, doc-14, doc-24 and backend/.env.example updated
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
