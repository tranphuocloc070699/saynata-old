---
id: TASK-102.6
title: 'Web History and Liked page, with lookups synced in batches'
status: To Do
assignee: []
created_date: '2026-10-25 07:37'
labels:
  - web
dependencies:
  - TASK-93.3
parent_task_id: TASK-102
priority: high
ordinal: 128000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Learners who use the phone and the website should see one History and one Liked list. The web records its own lookups and stars the same way as the app: shown at once, sent in batches to /api/sync. Mockup chosen 2026-10-25 (developer): History | Liked segments with search and clear, Settings with Translation and History cards, Account with profile, three counts and delete account. Icon-only buttons, Sage and Teal tokens, opened from the header account menu.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 /history shows History and Liked as two segments, grouped by day, newest first, with a search box
- [ ] #2 Each row has icon-only star and remove buttons; clicking a row opens it on the home page; clear-all asks first
- [ ] #3 A web lookup or star shows at once and is queued in localStorage, then sent as one /api/sync batch (debounced, and on page hide with keepalive)
- [ ] #4 A guest sees a sign-in prompt instead of the list; Vitest tests cover the queue and the merge
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
