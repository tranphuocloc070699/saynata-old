---
id: TASK-128.3
title: 'iOS/Mac: Analytics protocol with Sentry and PostHog'
status: To Do
assignee: []
created_date: '2026-11-04 10:35'
labels:
  - analytics
dependencies:
  - TASK-128.1
references:
  - 'https://developer.apple.com/app-store/user-privacy-and-data-use/'
parent_task_id: TASK-128
ordinal: 162000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The app (and the Mac app and extensions, which compile the app folder) needs crash reports and the shared events. Follows the project rule: system APIs behind a small protocol with a fake for tests.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 An Analytics protocol is injected like the other stores; tests use a fake and check that key flows send the right event
- [ ] #2 Events from the shared list fire from the app, Share extension, App Intents and the Mac panel with the right source
- [ ] #3 Crashes and errors reach Sentry for iOS and Mac; nothing is sent in Debug unless turned on
- [ ] #4 A Share usage data switch in Settings (opt-out) stops all events; its design comes from a mockup the developer picked
- [ ] #5 PrivacyInfo.xcprivacy declares Product Interaction and Crash Data for analytics, linked to the user, no tracking (no IDFA); coordinate with TASK-112
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
