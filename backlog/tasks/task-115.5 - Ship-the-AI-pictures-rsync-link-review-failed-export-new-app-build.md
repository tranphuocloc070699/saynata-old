---
id: TASK-115.5
title: 'Ship the AI pictures: rsync, link, review failed, export, new app build'
status: To Do
assignee: []
created_date: '2026-10-25 15:11'
labels:
  - media
  - pipeline
  - ios
dependencies: []
parent_task_id: TASK-115
ordinal: 144000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Putting the pictures on production. Linking is data only (no backend deploy). Old media rows and files are kept, so old app versions still work.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Files copied to /var/lib/saynata/media with the right owner
- [ ] #2 media-ai --link done; passed senses point to AI media (ai_generated)
- [ ] #3 Failed senses fixed: uploaded by hand or image_type none; no Pixabay fallback
- [ ] #4 A sample of linked senses checked in the admin Media to review chip
- [ ] #5 pipeline export run and a new app build ships the new bundled file
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
