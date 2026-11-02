---
id: TASK-123
title: 'iOS: Fix card in the Translate sheet (fix text the user writes in other apps)'
status: In Progress
assignee: []
created_date: '2026-11-02T16:21:00Z'
labels:
  - ios
dependencies: []
references:
  - docs/design/mockups/translate-fix-option-a.html
ordinal: 155000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Option A (doc-7, 2026-11-02). When Saynata is the default translation app and the user selects text they are writing (Telegram, Discord), the Translate sheet shows the fixed English text (better + betterWhy from the sentence answer, TASK-110) on top with an icon-only Replace button that puts it back via TranslationUIProviderContext.finish(translation:). Text the user is only reading keeps today's explain sheet. No backend change. Mockup: docs/design/mockups/translate-fix-option-a.html
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Writable selection of a sentence shows the Fix card above the explanation: spinner, then the fix with bold changes and the reason, or 'No mistakes found.'
- [ ] #2 Replace puts the fixed English text in place of the selection, keeps surrounding spaces, and closes the sheet
- [ ] #3 Read-only selections and the share extension show no Fix card
- [ ] #4 FixStatusTests pass; doc-10 updated
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
