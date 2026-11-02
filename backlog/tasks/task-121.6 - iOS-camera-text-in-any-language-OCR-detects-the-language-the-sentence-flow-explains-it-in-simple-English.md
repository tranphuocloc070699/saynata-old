---
id: TASK-121.6
title: >-
  iOS: camera text in any language (OCR detects the language, the sentence flow
  explains it in simple English)
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02T16:45:00Z'
labels:
  - ios
dependencies: []
parent_task_id: TASK-121
ordinal: 163000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The developer asked whether a photo of text in another language (Vietnamese, Korean...) can be read and explained in English. The camera only recognises en-US today. The backend sentence flow already accepts other languages (prompt v12+: the English version, then the simple English explanation, the language line last), so only the text recognition needs to change.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Photo text and live text detect the language (at least the app's target languages and English)
- [ ] #2 Captions no longer say English-only text
- [ ] #3 Swift Testing test for the language list
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
