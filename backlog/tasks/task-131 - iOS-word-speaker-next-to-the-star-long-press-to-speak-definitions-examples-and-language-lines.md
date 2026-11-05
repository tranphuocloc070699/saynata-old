---
id: TASK-131
title: >-
  iOS: word speaker next to the star; long press to speak definitions, examples
  and language lines
status: To Do
assignee: []
created_date: '2026-11-04T17:12:00Z'
labels:
  - ios
dependencies: []
priority: medium
ordinal: 168000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Developer's request 2026-11-04: move the IPA chip's speaker to the header next to the star (icon-only), remove the speaker button from each Examples row, and let a long press on an example, a definition or the target-language line open a small popover with a speak icon. Related to TASK-48 (Examples rows). Mockup first.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Mockup approved by the developer
- [ ] #2 Header: speaker icon next to the star; the IPA stays, without its own speaker
- [ ] #3 Examples rows have no speaker button; long press on an example, a definition or the language line shows a popover with a speak icon that reads that text
- [ ] #4 VoiceOver can still speak each text (accessibility action)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
