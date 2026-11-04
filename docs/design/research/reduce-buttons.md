# Fewer buttons on the result screens (2026-11-04)

## Important limit of this report
The Mobbin search tool was not available in this session. I could not search Mobbin, look at screens, or get `mobbin_url` links.
The app names below come from my general knowledge of how these apps behave. They are NOT checked on Mobbin and have no links.
Before the developer decides, someone should open each named screen on Mobbin (search the app name) and confirm it.
No SwiftUI code was changed.

## Count today (from the code)
Sentence result (`SentenceCard.swift`):
- Summary: Listen + Like (line 154-158)
- Opened original: Listen (129)
- Better way to say it: Listen + Copy (181-187)
- Under the card: Copy (60)
- Total: up to 6 icon buttons, 3 of them are Listen.

Word result (`WordCardView.swift`, `SenseTitleRow.swift`, `WordExamplesSection.swift`):
- Header: Listen + Like (58-64)
- Each sense: Listen (SenseTitleRow 43-55)
- Each example: Listen (WordExamplesSection 29-40)
- A word with 3 senses and 2 examples each: about 11 buttons. Listen is 9 of them.

Main problem: Listen is repeated on every block. Copy is repeated too.

## Patterns real apps use (to verify on Mobbin)
- Tap the text itself to hear it. Apple Translate and Google Translate show one speaker for a whole result. Cambridge and Oxford dictionary apps put one speaker next to the headword and let examples be tapped or have a small speaker.
- One action bar under the content. ChatGPT and Claude put Copy, Listen, Like under a message, once, not on every paragraph.
- Overflow "..." menu. Claude and ChatGPT message actions, Readwise highlights: secondary actions (Copy, Share) hide in a menu.
- Long-press context menu (Apple HIG: [Context menus](https://developer.apple.com/design/human-interface-guidelines/context-menus)). Copy, Share, Listen slowly on hold.
- Swipe actions are for lists (History, Liked), not for a result card. Good for deleting or un-liking there.
- Reading apps (LingQ, Readwise Reader) use a player bar once for the whole page.

## Option A: One action bar per result (like Claude / ChatGPT messages)
Keep: one row under the card with Listen, Like, Copy.
Remove: Listen on the opened original, Listen+Copy on "Better", the separate Copy under the card.
- Sentence: bar = Listen (simple summary), Like, and a "..." with Copy original / Copy better / Listen original / Listen better. Better block keeps zero buttons.
- Word: header keeps Listen (word) + Like. Sense and example Listen buttons are removed; the whole sense definition and each example are tap-to-hear (text has speech highlight already, so the user sees what plays).
- Result: sentence 3, word 2. Risk: tap-to-hear is hidden; add a one-time hint.

## Option B: Tap text to hear, one "..." menu
Keep: Like (and Listen for the headword/summary only). Everything else in a "..." menu on the card header.
- Sentence: summary text tap = play. Icons: Like, "...". Menu: Copy original, Copy better, Listen original, Listen better.
- Word: headword Listen + Like + "...". Senses and examples: tap to hear. Menu: Copy word, Share.
- Result: sentence 2, word 3. Cleanest look; Copy takes 2 taps.

## Option C: Keep icons only where the learner practises; rest in long-press
Keep: Listen on the summary, on "Better", on the headword; Like.
Move: Copy to long-press (system `textSelection` already exists, lines 83, 176) and a context menu; remove Listen from the opened original and from every sense/example (examples keep one Listen each only in the expanded "Examples" folded row).
- Result: sentence 3 (Listen, Like, Listen-better), word 2 plus example speakers only when "Examples" is open.
- Lowest risk, smallest change. Still some repeated Listen.

## Recommendation
Option A, with one tweak from B: make text tap-to-hear for senses and examples, and put Copy into a "..." on the sentence bar.
Why: it matches the Claude-app feel the developer wants (one action row under content), removes the repeated Listen (the biggest source), and keeps the most-used actions (Listen, Like) visible. Long-press Copy (system selection) stays as a free extra.
Rules check: all remain icon-only with accessibility labels (CLAUDE.md "icon-only buttons"). A tappable text block needs `.accessibilityAddTraits(.isButton)` and a label like "Listen to the explanation" so VoiceOver users still find it.

## Next steps
1. Verify the named apps on Mobbin and save links (`docs/design/refs/`).
2. Make a mockup of Option A for sentence and word (project rule: mockup before UI code).
3. After the developer picks, create small Backlog tasks (not created yet).
