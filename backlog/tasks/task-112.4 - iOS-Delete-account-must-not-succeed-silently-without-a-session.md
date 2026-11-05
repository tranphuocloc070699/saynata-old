---
id: TASK-112.4
title: 'iOS: Delete account must not succeed silently without a session'
status: Done
assignee:
  - '@claude'
created_date: '2026-11-04T15:23:00Z'
updated_date: '2026-11-04T16:51:00Z'
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
- [x] #1 deleteAccount throws a clear error when there is no session or the token cannot be refreshed
- [x] #2 Settings shows the error and offers sign-in again
- [x] #3 Tests cover the missing and expired session cases
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Tests pass
- [x] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [x] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. AccountStore.deleteAccount throws AccountError.signInRequired when no session or refresh gives nil
2. Settings: on that error sign out locally and show 'Sign in again to delete your account.' (existing error text, existing sign-in row)
3. Swift Testing: no session, expired refresh, success
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
AccountStore.deleteAccount throws AuthError.signInRequired (no session, or refresh refused; device signed out). A refresh that fails for another reason keeps the session. Settings: the message shows in the Sign in card's hint line (error colour, same layout); tapping the card clears it. Tests in AccountStoreTests, not run here (no Xcode on Linux).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
deleteAccount throws AuthError.signInRequired when there is no session or the refresh is refused (the device is signed out); a server error during the refresh keeps the session. Settings shows the message in the Sign in card's hint line and tapping it opens sign-in. Swift Testing tests in AccountStoreTests. PR #265, tested by the developer 2026-11-04.
<!-- SECTION:FINAL_SUMMARY:END -->
