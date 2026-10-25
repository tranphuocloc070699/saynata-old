---
id: TASK-115.6
title: 'Verify zero Pixabay pictures, then clean up and remove Pixabay code'
status: To Do
assignee: []
created_date: '2026-10-25 15:12'
labels:
  - media
  - backend
  - pipeline
  - admin
dependencies: []
parent_task_id: TASK-115
ordinal: 145000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Do not delete old Pixabay files while old app versions and phone caches still load them (Caddy caches files for a year). Wait until most users are on the new app. Then remove files, rows and code.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Query shows zero linked senses with media.source = pixabay
- [ ] #2 Waiting period over (most users on the new app version), decision recorded in doc-7
- [ ] #3 Unused Pixabay media rows and files deleted; the R2 backup (TASK-107) includes the new files
- [ ] #4 Pixabay code removed: backend HttpPixabayClient, pipeline media.py, admin Pick panel, env keys, pipeline/licenses/NOTICE.md credit
- [ ] #5 doc-15, doc-6, doc-14, doc-24 and doc-7 updated; python3 scripts/check_docs.py passes
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
