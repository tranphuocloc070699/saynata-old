---
id: TASK-112.7
title: >-
  iPhone checks before submission: Share open-app, large text, extension memory,
  spelling freeze
status: To Do
assignee: []
created_date: '2026-11-04T15:23:00Z'
labels:
  - app-store
dependencies: []
parent_task_id: TASK-112
priority: medium
type: task
ordinal: 165000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Findings 6, 8, 11 and 12 of the CodeRabbit App Store review 2026-11-04 can only be confirmed on a real device. Check each; create a fix task only for what fails.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Share sheet 'Open in Saynata' works from Safari and Notes on iOS 18; if not, the button is hidden
- [ ] #2 At the largest accessibility text size the input row and the 6-digit code boxes fit on iPhone 16 Pro and in both extensions
- [ ] #3 The Share and Translate sheets do not crash on words with pictures and clips
- [ ] #4 A misspelled word shows suggestions without a visible freeze
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
