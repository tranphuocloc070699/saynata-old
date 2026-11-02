---
id: TASK-121.1
title: >-
  Backend: POST /api/vision/identify (Gemini vision) and answerable dish and
  vision labels
status: In Progress
assignee:
  - '@implementer'
created_date: '2026-11-02T15:51:00Z'
updated_date: '2026-11-02T16:34:00Z'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Feature.VISION + GeminiClient.describeImage (image_url data URI on the OpenAI-compatible endpoint, same Reply).
2. Flyway V40 vision_identify (hash+prompt version unique, label, kind, confidence, model, created_at; no photo).
3. vision package: VisionController (multipart image, 2 MB, JPEG/PNG), VisionService (cache first, then ClaudeGate, Gemini, usage record), VisionLabels (dishes.txt allow-list + stored labels).
4. WordService: dish alias to accented form; dish or vision label acts like a wordMatch.
5. Tests VisionIdentifyApiTest, VisionLabelsTest; docs doc-24, doc-7; check_docs.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Built: Feature.VISION, GeminiClient.describeImage (image_url data URI on the OpenAI-compatible endpoint), Flyway V40 vision_identify, package vision/ (controller, service, VisionLabels), WordService treats dishes (accent alias) and stored vision labels like a wordMatch. Tests: Vision* and Word* pass (58 tests). Docs: doc-24, doc-5, doc-7.

Test it: curl -F image=@photo.jpg with a Bearer token to POST /api/vision/identify gives {label,kind,confidence}; same photo again is a cache hit; GET /api/words/phở and /pho describe the dish; guest 401 sign_in_required, over 2 MB 413 file_too_large, not an image 400 invalid_image. Automated: cd backend && ./mvnw -B test -Dtest='Vision*,Word*'.

Merged into feature/f8-camera-explain 2026-11-02. Waits for the developer's Xcode build and phone test (PR #243 into feature/local).
<!-- SECTION:NOTES:END -->
