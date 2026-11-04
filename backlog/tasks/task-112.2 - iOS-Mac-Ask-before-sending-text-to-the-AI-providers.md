---
id: TASK-112.2
title: 'iOS/Mac: Ask before sending text to the AI providers'
status: To Do
assignee: []
created_date: '2026-11-04T15:23:00Z'
labels:
  - app-store
  - privacy
dependencies: []
parent_task_id: TASK-112
priority: high
type: feature
ordinal: 160000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Apple guideline 5.1.2 (third-party AI): the app sends looked-up text to our server, which asks DeepSeek (Gemini as fallback). The app must say so and get permission first. Prefetch while typing also sends text, so the permission must come before the first keystroke is sent (CodeRabbit App Store review 2026-11-04, finding 2).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A one-time screen explains, in plain English, that text goes to our server and an AI provider (named), with a link to the privacy policy
- [ ] #2 No text is sent (typing prefetch, lookup, Share/Translate sheet, Quick explain) before the learner agrees
- [ ] #3 Settings shows the choice and lets the learner withdraw it; withdrawn, lookups only use the bundled dictionary
- [ ] #4 Design comes from a mockup the developer picked
- [ ] #5 Tests cover: no request before consent, including prefetch
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
