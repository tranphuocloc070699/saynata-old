---
id: TASK-121.2
title: 'Model: MobileCLIP2 to Core ML, label vectors and food layer weights'
status: To Do
assignee:
  - '@claude'
created_date: '2026-11-02T15:51:00Z'
labels:
  - ios
  - pipeline
dependencies: []
parent_task_id: TASK-121
ordinal: 158000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The phone needs the image encoder as Core ML, the precomputed text vectors of its labels (dictionary nouns + 30 dishes) and the trained food layer. Built offline by a script in scripts/vision_spike/.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 One script builds the .mlpackage, the label vectors and the food layer weights; safe to run again
- [ ] #2 Model size reported; S2 if the app grows less than about 60 MB, else S0
- [ ] #3 Outputs reach the app through the repo's large-file method (LFS or a download step)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
