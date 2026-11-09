---
id: TASK-130
title: 'iOS + Mac: all icons from Lucide'
status: To Do
assignee: []
created_date: '2026-11-04T17:12:00Z'
labels:
  - ios
dependencies: []
priority: low
ordinal: 167000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Developer's request 2026-11-04: replace the SF Symbols in the app (IconButton, rows, chips, tab and toolbar icons) with Lucide icons. Pick how to ship them (a Swift package or bundled SVG assets), map every SF Symbol in use to a Lucide icon, mockup of the main screens first.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Developer approved the icon mapping and the way Lucide is added (package or assets)
- [ ] #2 Every SF Symbol in EnglishTranslation/ and SaynataMac/ is replaced, accessibility labels unchanged
- [ ] #3 docs/design/design-system.md lists the icon set and mapping
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
