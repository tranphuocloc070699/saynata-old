---
id: TASK-93.3
title: 'Backend: batch sync for History, Liked and settings (/api/sync)'
status: To Do
assignee: []
created_date: '2026-10-25 07:37'
labels:
  - backend
dependencies: []
documentation:
  - backlog/docs/features/doc-22 - History-and-Liked.md
parent_task_id: TASK-93
priority: high
ordinal: 126000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Decision 2026-10-25 (developer): History is no longer device-only. When a signed-in user looks something up or likes it, it should follow them to the Mac app and the website. Calls are batched so a fast typer does not send one request per lookup; the device always shows the change first and syncs in the background. Settings (target language, Show translation) also follow the account; the default Show translation becomes Remember last choice. Liked today is one PUT/DELETE per tap (TASK-93.1); it moves into the same batch. Today's per-call /api/liked stays for old app builds.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 POST /api/sync takes a list of ops (history add/remove/clear, liked add/remove, each with a client time) and a since cursor, applies them last-write-wins, and returns the changes since the cursor plus a new cursor
- [ ] #2 History rows per account are stored in a new Flyway table with the same key rule as SavedItem (word lowercased and trimmed, sentence trimmed), capped at 1000 per user
- [ ] #3 Removes and clear-all are kept as tombstones so other devices also delete the item
- [ ] #4 GET and PUT /api/me/settings store target language, Show translation mode (default remember) and Sync history (default on); turning Sync history off deletes the server history
- [ ] #5 GET /api/me also returns sign-in method, member-since date, history and liked counts and today's AI use and limit for the web Account page
- [ ] #6 A guest gets 401 sign_in_required; a batch over a size limit gets 400; JUnit tests cover merge order, tombstones, cap, and guest
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
