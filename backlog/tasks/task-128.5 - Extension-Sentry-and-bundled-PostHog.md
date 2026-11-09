---
id: TASK-128.5
title: 'Extension: Sentry and bundled PostHog'
status: To Do
assignee: []
created_date: '2026-11-04 10:36'
labels:
  - analytics
dependencies:
  - TASK-128.1
references:
  - >-
    https://docs.sentry.io/platforms/javascript/best-practices/shared-environments/
  - >-
    https://developer.chrome.com/docs/extensions/develop/migrate/remote-hosted-code
parent_task_id: TASK-128
ordinal: 164000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Chromium MV3 extension runs inside other sites. MV3 forbids remote code, so SDKs must be bundled, and Sentry must not use the global init in content scripts (it would mix with the host page).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Errors from the background worker and the content card reach Sentry through a manual BrowserClient, not Sentry.init in content scripts
- [ ] #2 PostHog is bundled (no CDN script) and sends lookup_done with source extension and the other shared events
- [ ] #3 No selected page text or page URL is sent
- [ ] #4 The store listing privacy answers are updated to name usage data and crash data
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
