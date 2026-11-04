---
id: TASK-126
title: Fewer buttons on sentence and word cards (mockup A)
status: In Progress
assignee: []
created_date: '2026-11-04T05:48:00Z'
updated_date: '2026-11-04T05:49:00Z'
labels:
  - ios
  - ui
dependencies: []
ordinal: 157000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Developer chose mockup A (docs/design/mockups/fewer-buttons.html): one quiet action row under the sentence summary (Listen, Like, Copy original); Listen inside the IPA chip on the word header; tap a sense explanation or the better version to hear it. Also fixes the summary showing **stars** (Markdown not read) and makes the summary body size.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Sentence card: plain Listen, Like, Copy row under 'In simple words'; no Copy under the card
- [ ] #2 Better way to say it: tap text to hear, one Copy icon
- [ ] #3 Word header: speaker in the IPA chip, only Like on the right
- [ ] #4 Sense explanation is tap-to-hear with button trait; no speaker button
- [ ] #5 Summary shows **bold** key words, body size
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Mockup A (docs/design/mockups/fewer-buttons.html), 2026-11-04. Changed: SentenceCard.swift (actionRow under 'In simple words': Listen, Like, Copy original; Copy under the card removed; Better way to say it: tap text to hear, one plain Copy; summary uses style .summary), SenseTitleRow.swift (TapToHear, no speaker), WordHeaderView.swift (onListen: speaker in the IPA chip), WordCardView.swift, LikeButton.swift (style param). Exception: the opened original keeps one plain speaker because its words are tappable. Compact card and share sheet unchanged. Docs: doc-4, doc-5, doc-7 updated. Not built on Linux: needs Cmd+U in Xcode.
<!-- SECTION:NOTES:END -->
