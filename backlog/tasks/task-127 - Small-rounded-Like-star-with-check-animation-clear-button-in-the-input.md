---
id: TASK-127
title: Small rounded Like star with check animation; clear button in the input
status: In Progress
assignee: []
created_date: '2026-11-04 06:22'
updated_date: '2026-11-04 07:30'
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

Developer test 2026-11-04 (feature/local, after PR 251): (1) Remove the bottom border/hairline under the target-language row (e.g. 'Vietnamese') on word sense cards. (2) After typing, the language chip in the input card is clipped on the left ('ietnamese') - likely the clear (x) button appearing/disappearing animates the HStack and clips the Menu label. Developer wants animations reduced as much as possible across the whole iOS UI: UX over visual effects. Audit every withAnimation/.animation/.transition/symbolEffect in EnglishTranslation/, list them, propose which to remove, then fix. Screenshots in the original chat.

Fix PR 252 (fix/fewer-animations -> feature/local): language chip keeps full width (.fixedSize), FoldedRow showsDivider=false on all 4 target-language rows. Build passes on iPhone 16 Pro 18.5; not checked on device. Animation audit done (FoldedRow:21, SentenceCard:97, SpeechPlayer:77, LikeButton:71-75, SignInSheet:65-66, CatSpriteEngine CA keyframes); removal waits for the developer's choice.

Developer chose to remove animations 1-4 (FoldedRow, SentenceCard Original, speechHighlight, SignInSheet); done in PR 252. Like animation and cat sprite kept.

2026-11-04: chip clipping still seen after PR 255 (screen recording ~/Downloads/ScreenRecording_11-04-2026 14-22-44_1.MP4). PR 256 pins the input card to full width (card width followed the text). If it still clips: watch the recording frame by frame; next idea is replacing the Menu label with a fixed-width frame.

Recording showed the real cause: clipping right after picking a language (menu close morph to the old width), not typing. PR 257 adds .id(targetLanguage) to the menu. Not yet tested on the phone.
<!-- SECTION:NOTES:END -->
