---
id: TASK-102.4
title: Web privacy policy and terms pages
status: To Do
assignee: []
created_date: '2026-10-24 17:30'
labels: []
dependencies: []
parent_task_id: TASK-102
ordinal: 123000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Google brand verification (needed to show the Saynata logo in the Google sign-in popup on web and iOS) asks for a working privacy policy URL and terms URL on saynata.com. The web app has only the homepage, so these pages do not exist yet. They also help the App Store review and Sign in with Apple.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `https://saynata.com/privacy` shows a privacy policy: what data Saynata keeps (email, sign-in identities, history and liked items, Claude usage), why, and how to delete the account
- [ ] #2 `https://saynata.com/terms` shows the terms of use
- [ ] #3 Both pages are linked from the homepage footer and from the sign-in page
- [ ] #4 Vitest covers that both routes render
- [ ] #5 doc-23 lists the two routes
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
