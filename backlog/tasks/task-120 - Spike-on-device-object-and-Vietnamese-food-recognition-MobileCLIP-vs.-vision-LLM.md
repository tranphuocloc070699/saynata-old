---
id: TASK-120
title: >-
  Spike: on-device object and Vietnamese food recognition (MobileCLIP) vs.
  vision LLM
status: In Progress
assignee: []
created_date: '2026-11-02 15:19'
labels:
  - ios
  - backend
  - research
dependencies: []
ordinal: 155000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The developer wants a camera feature: point the phone at a thing (a desk, a bowl of phở, bánh mì) and see its simple English explanation (explain first, translate last). Common object detectors (COCO YOLO, ML Kit) do not know 'desk' or Vietnamese dishes, so the plan is a cascade: MobileCLIP on the phone with Saynata's own dictionary nouns as labels, a small trained layer for Vietnamese dishes, and a vision LLM on the backend when the phone is unsure. This spike measures accuracy and speed before any UI or backend code. Test data: 30VNFoods on Hugging Face (vuongnhathien/30VNFoods, CC BY-NC-SA 4.0, test only, not committed) and ImageNet validation photos (research use only, not committed). Wikimedia Commons blocks the cloud session IP.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 scripts/vision_spike has runnable uv scripts for the zero-shot test and the food layer, with a README of results
- [ ] #2 README reports top-1/top-5 accuracy and confidence vs. coverage for objects and for Vietnamese dishes
- [ ] #3 README compares MobileCLIP with a vision LLM (Gemini) on the same photos
- [ ] #4 README ends with a recommended cascade and thresholds for the iOS feature
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
