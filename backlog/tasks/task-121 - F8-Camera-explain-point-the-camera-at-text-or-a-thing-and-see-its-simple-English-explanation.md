---
id: TASK-121
title: >-
  F8 Camera explain: point the camera at text or a thing and see its simple
  English explanation
status: To Do
assignee:
  - '@claude'
created_date: '2026-11-02T15:51:00Z'
labels:
  - ios
  - backend
dependencies:
  - TASK-120
priority: high
type: feature
ordinal: 156000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The developer wants a camera on the main screen: read text (live or from a photo) into the sentence flow, or point at a thing (a desk, a bowl of phở, a bánh mì) and open its word card. Explain first, translate last. Recognition is a cascade measured in TASK-120 (scripts/vision_spike/README.md): MobileCLIP2 zero-shot on the phone with dictionary nouns as labels, a trained food layer for 30 Vietnamese dishes, and a Gemini vision call on the backend when the phone is unsure. Branch feature/f8-camera-explain; each subtask is a PR into it, then it goes into feature/local.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Text mode: live camera text or a library photo goes into the existing sentence flow
- [ ] #2 Object mode: a tappable label on screen opens the normal word card; unsure results show 3 chips and an ask-AI icon button
- [ ] #3 The developer installs it on the iPhone with scripts/install-on-phone.sh and it works
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
