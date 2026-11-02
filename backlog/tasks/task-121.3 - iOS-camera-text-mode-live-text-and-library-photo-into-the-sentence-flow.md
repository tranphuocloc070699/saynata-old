---
id: TASK-121.3
title: 'iOS: camera text mode (live text and library photo into the sentence flow)'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02T15:51:00Z'
updated_date: '2026-11-02T16:26:00Z'
labels:
  - ios
dependencies:
  - TASK-121.2
parent_task_id: TASK-121
ordinal: 159000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Text mode of the camera screen: VisionKit DataScannerViewController for live text, Vision RecognizeTextRequest for a library photo. The picked text goes into the existing sentence flow; no new LLM prompt.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Live text and a library photo both give tappable text and an all-text choice
- [ ] #2 The picked text opens the sentence result
- [ ] #3 Camera and Vision sit behind protocols; Swift Testing tests use fakes
- [ ] #4 NSCameraUsageDescription and NSPhotoLibraryUsageDescription in plain English
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Logic + tests in draft PR #239; SwiftUI layout waits for the mockup choice (https://claude.ai/artifact/GQbtRYUtwQgLemGNJDPVHu).
<!-- SECTION:NOTES:END -->
