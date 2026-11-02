---
id: TASK-122
title: >-
  Retrain the food layer on commercially usable photos before an App Store
  release
status: To Do
assignee: []
created_date: '2026-11-02T15:51:00Z'
labels:
  - ios
  - pipeline
dependencies:
  - TASK-121
type: chore
ordinal: 162000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The F8 food layer is trained on 30VNFoods, which is CC BY-NC-SA 4.0 (non-commercial). Before the app ships on the App Store, retrain it on our own photos or a dataset with a commercial license, and check how often it calls a non-food photo a dish.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Food layer trained only on photos we may use commercially, source and license recorded
- [ ] #2 Accuracy measured again with the same script and reported in scripts/vision_spike/README.md
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
