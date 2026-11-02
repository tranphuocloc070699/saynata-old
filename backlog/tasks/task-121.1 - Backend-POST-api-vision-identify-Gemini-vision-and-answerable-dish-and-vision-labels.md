---
id: TASK-121.1
title: >-
  Backend: POST /api/vision/identify (Gemini vision) and answerable dish and
  vision labels
status: To Do
assignee:
  - '@claude'
created_date: '2026-11-02T15:51:00Z'
labels:
  - backend
dependencies: []
parent_task_id: TASK-121
ordinal: 157000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When the phone is unsure, it sends one photo to the backend. Gemini names the thing; the app then calls GET /api/words/{label}. Today that endpoint rejects words not on the SCOWL/NGSL list, so dish names (phở, bánh mì) and new vision labels would show 'not an English word'.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 POST /api/vision/identify (multipart, max 2 MB) returns {label, kind, confidence}; signed-in only, through limits/ClaudeGate with Feature.VISION
- [ ] #2 Answers are cached by image hash in a new Flyway table; the photo itself is never stored
- [ ] #3 GET /api/words/{label} answers the 30 dishes and labels the vision endpoint returned
- [ ] #4 @SpringBootTest tests with a fake key; no real API call
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
