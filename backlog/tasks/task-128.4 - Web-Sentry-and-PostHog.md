---
id: TASK-128.4
title: 'Web: Sentry and PostHog'
status: To Do
assignee: []
created_date: '2026-11-04 10:35'
labels:
  - analytics
dependencies:
  - TASK-128.1
parent_task_id: TASK-128
ordinal: 163000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The learner website (homepage, sign-in, sign-up) needs error reports and the shared events, so web sign-ups can be compared with app use.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Client and server errors of the Next.js app reach Sentry
- [ ] #2 PostHog records page views and the shared events that exist on web, with the same names as iOS
- [ ] #3 Keys come from env; tests run without sending anything
- [ ] #4 Signed-in users are identified by user ID only, never email
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
