---
id: TASK-112.6
title: 'iOS: Check the result of SecRandomCopyBytes in SignInSecrets'
status: To Do
assignee: []
created_date: '2026-11-04T15:23:00Z'
labels: []
dependencies: []
parent_task_id: TASK-112
priority: low
type: bug
ordinal: 164000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
SignInSecrets.random() ignores the status of SecRandomCopyBytes; on failure the nonce and secrets are all zeros (CodeRabbit App Store review 2026-11-04, finding 13).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A failed random call fails the sign-in with a visible error instead of using zeros
- [ ] #2 A test injects a failing random source
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
