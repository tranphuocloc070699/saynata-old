---
id: TASK-115
title: Replace all Pixabay pictures with AI pictures on production
status: To Do
assignee: []
created_date: '2026-10-25 15:11'
labels:
  - media
  - pipeline
  - backend
dependencies: []
references:
  - backlog/docs/features/doc-15 - Media-and-images.md
ordinal: 139000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Pixabay photos and clips are the sense media today. The developer wants every picture on production to be an AI picture (cartoon style from media-ai, TASK-82), so the app has one style and no Pixabay dependency. Decisions (2026-10-25): verbs also get a still AI picture and their clips are dropped; senses that fail the meaning check after 3 tries get a hand upload or image_type none, never a Pixabay fallback; backend words (word_lookup_media) are included. Old Pixabay files stay on the server until most users run the new app, because old app versions and the phone cache still load them. See doc-15 (Media and images).
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
