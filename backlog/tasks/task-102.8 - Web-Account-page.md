---
id: TASK-102.8
title: Web Account page
status: To Do
assignee: []
created_date: '2026-10-25 07:38'
labels:
  - web
dependencies:
  - TASK-93.3
parent_task_id: TASK-102
ordinal: 130000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Signed-in learners have no place on the website to see their account, sign out or delete it (the App Store-style delete exists only in the app). Mockup chosen 2026-10-25 (developer): History | Liked segments with search and clear, Settings with Translation and History cards, Account with profile, three counts and delete account. Icon-only buttons, Sage and Teal tokens, opened from the header account menu.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 /account shows the email, sign-in method and member-since date, history and liked counts, and today's AI use against the limit
- [ ] #2 Icon-only Sign out and Delete account buttons; delete asks first and calls DELETE /api/me, then goes home signed out
- [ ] #3 The header account menu links to History, Settings and Account; a guest is sent to /sign-in
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
