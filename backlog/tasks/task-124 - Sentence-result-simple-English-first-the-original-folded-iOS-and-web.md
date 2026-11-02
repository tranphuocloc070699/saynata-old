---
id: TASK-124
title: 'Sentence result: simple English first, the original folded (iOS and web)'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02T17:15:00Z'
updated_date: '2026-11-02T17:22:00Z'
labels:
  - ios
  - web
dependencies: []
type: feature
ordinal: 156000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The developer finds the original sentence at the top of the sentence result annoying (screenshot 2026-11-02, iOS share sheet). They want the simple English version first, the better version next when there is one, and the original hidden behind a row or text they can open. Applies to the iOS app (and its share/translation extensions, which use the same card) and the web app.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The simple English summary is the first text of the sentence result
- [ ] #2 The better version (when there is one) shows right after it
- [ ] #3 The original sentence is hidden and opens from a visible row or text
- [ ] #4 Same order on iOS and web
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Mockup https://claude.ai/artifact/6oAiqufMFnchTNw2UD9fww: A (original as a closed row above the language row), B (original as one muted line at the top); web uses the same order. Waiting for the developer's choice.

Built option B on iOS (SentenceCard.swift: originalBlock, summary as .title3 headline with Listen and Like, betterBlock open) and web (SentenceCard.tsx: original line button, Summary headline, better open before words). Web: vitest 185 passed, eslint clean. iOS not compiled (no Mac). Share and Translation extensions use the same card.
<!-- SECTION:NOTES:END -->
