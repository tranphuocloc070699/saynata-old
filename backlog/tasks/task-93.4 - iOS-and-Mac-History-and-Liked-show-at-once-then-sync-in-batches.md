---
id: TASK-93.4
title: 'iOS and Mac: History and Liked show at once, then sync in batches'
status: To Do
assignee: []
created_date: '2026-10-25 07:37'
updated_date: '2026-10-25 07:38'
labels:
  - ios
dependencies:
  - TASK-93.3
parent_task_id: TASK-93
priority: high
ordinal: 127000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The app keeps the instant local History (SQLite, App Group) and Liked copy, and adds an outbox so the server catches up in the background (decision 2026-10-25). The Share and Translate extensions add to the same outbox. Guests stay local; on sign-in the local history is uploaded once. Settings follow the account; Show translation default changes from Collapsed to Remember last choice.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A lookup or star shows in History/Liked at once and adds an op to a persistent outbox in the App Group folder
- [ ] #2 The outbox is sent as one POST /api/sync after 5 s idle, at 20 ops, or when the app goes to the background; failed sends stay and retry with backoff; the UI never waits on it
- [ ] #3 On launch and on return to foreground the app pulls changes from other devices and merges them into History and Liked
- [ ] #4 A like no longer undoes on a network error; it stays and syncs later. A guest still gets the sign-in sheet
- [ ] #5 Settings has a Sync history switch (on by default); changing language or Show translation is sent to /api/me/settings and read back on launch; default Show translation is Remember last choice
- [ ] #6 Swift Testing tests cover batching, retry, merge, and guest-to-signed-in upload with a fake API
- [ ] #7 CLAUDE.md product rule, doc-1 and doc-22 say the Show translation default is Remember last choice and History syncs for signed-in users
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
