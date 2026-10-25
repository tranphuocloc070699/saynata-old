---
id: TASK-115.3
title: 'Verbs get still AI pictures, drop Pixabay clips'
status: To Do
assignee: []
created_date: '2026-10-25 15:11'
updated_date: '2026-10-25 15:23'
labels:
  - media
  - pipeline
  - ios
dependencies: []
parent_task_id: TASK-115
ordinal: 142000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Verbs have 3-second Pixabay clips. AI makes still pictures only. Developer decision: verbs also get a still picture. Check how media-ai treats verbs and clip senses, and how the app and admin behave when a clip is replaced by a photo.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 media-ai draws a picture for verb senses that have a clip
- [ ] #2 Linking replaces the clip with the picture; image_type of such senses is photo
- [ ] #3 iOS and admin show the new picture where the clip was (checked by Test it steps)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Finding: no code change needed. media-ai pending query does not filter by media kind, so verb senses with a Pixabay clip are drawn; link() inserts kind photo and replaces the clip (existing test test_pg_link_also_replaces_a_clip_and_a_sense_without_media). image_type is photo/icon/none, clips are media.kind. iOS/admin display of the new photo where the clip was must be checked by Test it steps.
<!-- SECTION:NOTES:END -->
