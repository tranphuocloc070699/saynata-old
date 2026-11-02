---
id: TASK-121.4
title: 'iOS: camera object mode (cascade, label chips, ask AI)'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02T15:51:00Z'
updated_date: '2026-11-02T16:26:00Z'
labels:
  - ios
dependencies:
  - TASK-121.1
  - TASK-121.2
parent_task_id: TASK-121
ordinal: 160000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Object mode: MobileCLIP on the device a few frames per second, the food layer for dishes, chips when unsure, and an ask-AI icon button that calls POST /api/vision/identify. A tap opens the normal word card.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Cascade thresholds as in scripts/vision_spike/README.md (0.7)
- [ ] #2 Ask AI sends one JPEG of max 768 px and opens the word card for the answer
- [ ] #3 Store logic covered by Swift Testing with fake model and fake API
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Logic + tests in draft PR #240; layout waits for the mockup choice.
<!-- SECTION:NOTES:END -->
