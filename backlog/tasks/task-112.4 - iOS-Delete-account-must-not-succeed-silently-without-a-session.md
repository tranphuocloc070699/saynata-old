---
id: TASK-112.4
title: 'iOS: Delete account must not succeed silently without a session'
status: To Do
assignee: []
created_date: '2026-11-04T15:23:00Z'
labels:
  - app-store
dependencies: []
parent_task_id: TASK-112
priority: medium
type: bug
ordinal: 162000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
AccountStore.deleteAccount() returns without an error when there is no session or the refresh gives no token, so Settings looks like the account was deleted (CodeRabbit App Store review 2026-11-04, finding 10).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 deleteAccount throws a clear error when there is no session or the token cannot be refreshed
- [ ] #2 Settings shows the error and offers sign-in again
- [ ] #3 Tests cover the missing and expired session cases
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
