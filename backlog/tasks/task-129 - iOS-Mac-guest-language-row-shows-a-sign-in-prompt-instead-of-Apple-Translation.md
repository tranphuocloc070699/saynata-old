---
id: TASK-129
title: >-
  iOS + Mac: guest language row shows a sign-in prompt instead of Apple
  Translation
status: To Do
assignee: []
created_date: '2026-11-04T17:12:00Z'
labels:
  - ios
dependencies: []
priority: medium
ordinal: 166000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A guest's language row (non-Vietnamese) falls back to Apple Translation when the backend has no cached line, so iOS shows the 'Required downloads' sheet or 'Could not translate. The Japanese language pack...'. Developer's choice 2026-11-04: option C, show a sign-in prompt in the row instead. Mockup first.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Mockup of the guest row approved by the developer
- [ ] #2 A guest with no cached line sees the sign-in prompt in the row; tapping it opens the sign-in sheet; no Apple Translation download sheet
- [ ] #3 After sign-in the row loads the line from the backend
- [ ] #4 Signed-in users and cached lines work as before; Swift Testing tests cover the guest miss
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
