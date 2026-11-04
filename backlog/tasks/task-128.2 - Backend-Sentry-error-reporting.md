---
id: TASK-128.2
title: 'Backend: Sentry error reporting'
status: To Do
assignee: []
created_date: '2026-11-04 10:35'
updated_date: '2026-11-04 11:34'
labels:
  - analytics
dependencies: []
parent_task_id: TASK-128
ordinal: 161000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Server errors (LLM failures, DB errors) are only in logs today. Sentry shows them with stack traces and links them to client errors.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Unhandled exceptions and 5xx ProblemDetail responses are sent to Sentry; 4xx ApiExceptions (sign_in_required, limits) are not
- [ ] #2 SENTRY_DSN comes from env; with no DSN the backend runs and tests pass without sending anything
- [ ] #3 Request bodies (user text) are not attached to events
- [ ] #4 doc-11 and doc-24 list the new env key
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-11-04: sentry-spring-boot-4-starter 8.62.0 in pom.xml, sentry.* in application.properties (SENTRY_DSN, send-default-pii=false, no request bodies, traces 0.1), common/SentryScrub (BeforeSendCallback) drops query strings and the text in /api/words and /api/terms paths, SentryScrubTest. docker-compose.prod.yml passes SENTRY_DSN. Not verified with a real event yet: needs SENTRY_DSN in the VPS backend/.env and a deploy.
<!-- SECTION:NOTES:END -->
