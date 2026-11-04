---
id: TASK-112.5
title: 'iOS: Sync must not apply a response after the account changed'
status: To Do
assignee: []
created_date: '2026-11-04T15:23:00Z'
labels:
  - privacy
dependencies: []
parent_task_id: TASK-112
priority: medium
type: bug
ordinal: 163000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
SyncEngine.sendNow() awaits the server, then removes ops, sets the cursor and merges History and Liked without checking that the same account is still signed in. A late answer for account A can land after sign-out or sign-in as B (CodeRabbit App Store review 2026-11-04, finding 4).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A sign-out or account change cancels or invalidates a running sync (account generation check after every await)
- [ ] #2 A late response for the old account changes nothing locally
- [ ] #3 A test with a delayed fake response and an account switch passes
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
