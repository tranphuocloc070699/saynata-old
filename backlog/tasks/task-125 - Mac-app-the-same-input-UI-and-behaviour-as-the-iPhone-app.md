---
id: TASK-125
title: 'Mac app: the same input UI and behaviour as the iPhone app'
status: To Do
assignee:
  - '@claude'
created_date: '2026-11-03T00:22:00Z'
labels:
  - mac
dependencies: []
type: feature
ordinal: 156000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The developer wants the Mac app (menu-bar popover and the ⌥⇧Space panel, EnglishTranslation/SaynataMac/) to look and behave like the iPhone home screen: the composer card (TASK-97), language chip, send button, History and Settings, and the same result order (the simple-first sentence card, TASK-124). The results already use the shared TranslateResultView; the Mac input (MenuBarContentView) is its own code. The Mac app stays sandboxed for the Mac App Store (doc-7, 11-03).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A mockup of the Mac popover and panel is approved before any SwiftUI change
- [ ] #2 The Mac input, buttons and screens match the iPhone ones the developer picked
- [ ] #3 doc-20 updated
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
