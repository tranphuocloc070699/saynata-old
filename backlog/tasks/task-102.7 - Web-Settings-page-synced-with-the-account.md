---
id: TASK-102.7
title: Web Settings page synced with the account
status: To Do
assignee: []
created_date: '2026-10-25 07:37'
labels:
  - web
dependencies:
  - TASK-93.3
parent_task_id: TASK-102
ordinal: 129000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The website needs the same settings as the app so a change on one device shows on the others. Mockup chosen 2026-10-25 (developer): History | Liked segments with search and clear, Settings with Translation and History cards, Account with profile, three counts and delete account. Icon-only buttons, Sage and Teal tokens, opened from the header account menu. Default Show translation is Remember last choice.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 /settings has Language and Show translation (Collapsed, Always open, Remember last choice; default Remember) and a Sync history switch
- [ ] #2 A change applies at once and is sent to PUT /api/me/settings in the background; the page loads the account's settings on open
- [ ] #3 A guest's settings stay in localStorage; Vitest tests cover load and save
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
