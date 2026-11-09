---
id: TASK-128
title: Usage tracking and error reporting (Sentry + PostHog)
status: To Do
assignee: []
created_date: '2026-11-04 10:35'
labels:
  - analytics
dependencies: []
references:
  - 'https://sentry.io/pricing/'
  - 'https://posthog.com/pricing'
priority: medium
ordinal: 159000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The developer wants to know which features users like and to check the product goal (explain first, translate last). Nothing tracks usage or errors today. Decision 2026-11-04: Sentry for errors in every part (iOS/Mac, web, extension, backend), PostHog for feature events (not GA4: GA4 needs Firebase on iOS and only the Measurement Protocol in an MV3 extension). Both free tiers. Usage is not liking: read adoption, repeat use/retention and explicit signals (Like) together. Data is only useful after about 50 real users; the app is not on the App Store yet (TASK-112).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All three clients send the same event names from one shared event list
- [ ] #2 Errors from iOS/Mac, web, extension and backend arrive in Sentry
- [ ] #3 No looked-up text or other user content is sent to PostHog or Sentry
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
