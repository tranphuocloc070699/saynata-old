---
id: TASK-127
title: Small rounded Like star with check animation; clear button in the input
status: In Progress
assignee: []
created_date: '2026-11-04 06:22'
updated_date: '2026-11-04 06:25'
labels:
  - ios
  - ui
dependencies: []
ordinal: 158000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Word header Like star is a heavy 44 pt circle. Make it a small plain icon with a rounded star (custom Shape from the Lucide star path); on like, the star pops away, a check mark draws itself, then the filled star returns (mockup option B, docs/design/mockups/like-star-and-clear.html). Add a clear (x) button next to send in the input card, shown only when there is text; the counter keeps its near-limit rule (clear option A).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Like star on word headers is a plain small icon with a rounded star, same size as other plain result icons
- [ ] #2 Liking plays star -> drawn check -> filled star; unliking has no check; Reduce Motion skips the movement
- [ ] #3 Input card shows an x button with text, which clears the input; hidden when empty
- [ ] #4 Focused iOS tests pass on iPhone 16 Pro (iOS 18.5)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Built on fix/like-star-and-clear (based on the TASK-126 commit). LikeButton .plain = rounded star + check animation; .circle kept for the selected-text panel. Clear (x) in TranslateInputView. LikedStoreTests + TranslationStoreTests pass (45) on iPhone 16 Pro iOS 18.5.
<!-- SECTION:NOTES:END -->
