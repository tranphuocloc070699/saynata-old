---
id: TASK-121.7
title: >-
  iOS: camera text in place: English over other-language lines, tap a line to
  see its explanation at that spot
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02T16:59:00Z'
updated_date: '2026-11-02T17:09:00Z'
labels:
  - ios
dependencies: []
parent_task_id: TASK-121
ordinal: 164000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The developer wants the camera to work like iOS Live Text translate (screenshot 2026-11-02): when a line is in another supported language, English is drawn over it in the same place, live; tapping any line (English or not) shows its simple English explanation right there. Explain first still holds: the overlay is English (the language being learned), and the tap gives the simple English explanation with the language line last.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Non-English lines get an English line drawn over them in place, live and on photos
- [ ] #2 Tapping a line shows its simple English explanation anchored at that line
- [ ] #3 An icon-only button shows the original text again
- [ ] #4 Language detection and on-device translation sit behind protocols with Swift Testing fakes
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Mockup added to the F8 canvas (boards 5, 6A, 6B), waiting for the developer's choice. Planned: Apple Translation (on device) for the English line drawn over non-English text; NaturalLanguage to tell the language; the tap explanation from the existing sentence endpoint (cache first, sign-in for new).

Built after the developer chose 6A and the eye button top right: InPlaceText.swift, CameraTextStore (English per text, requests per language, select/close), TextLinesOverlay, LineExplanationCallout, translationTask in CameraScreen, InPlaceTextTests. Not compiled (no Mac).
<!-- SECTION:NOTES:END -->
