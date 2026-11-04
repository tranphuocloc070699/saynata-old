---
id: TASK-112.3
title: 'Backend + iOS: Revoke Sign in with Apple tokens when the account is deleted'
status: To Do
assignee: []
created_date: '2026-11-04T15:23:00Z'
labels:
  - app-store
  - backend
dependencies: []
parent_task_id: TASK-112
priority: high
type: task
ordinal: 161000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Apple asks apps with Sign in with Apple to revoke the user's Apple tokens on account deletion. The backend deletes the account but never calls Apple (CodeRabbit App Store review 2026-11-04, finding 3).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 iOS sends the Apple authorization code at sign-in; the backend exchanges it and stores the Apple refresh token (encrypted or as a secret column)
- [ ] #2 DELETE /api/me calls https://appleid.apple.com/auth/revoke for Apple accounts before deleting
- [ ] #3 A failed revoke is retried or logged, and the account is still deleted
- [ ] #4 Backend tests use a fake Apple endpoint; new env keys (team ID, key ID, private key) are in .env.example and doc-11
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
