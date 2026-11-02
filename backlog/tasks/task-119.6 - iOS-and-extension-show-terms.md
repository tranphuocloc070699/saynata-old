---
id: TASK-119.6
title: 'iOS, Mac and extension: show terms'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02 08:55'
updated_date: '2026-11-02 11:41'
labels:
  - ios
  - extension
dependencies: []
parent_task_id: TASK-119
ordinal: 154000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Show terms on iOS, the Mac app (same app folder) and the extension, like the web app (TASK-119.3). The developer said no mockup is needed (2026-11-02). Bundled words never ask the backend, so their terms come from a small GET /api/terms/{text} endpoint, fetched after the card is shown (online only). Buttons are icon-only (official site, Wikipedia) with VoiceOver labels.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Backend: GET /api/terms/{text} returns the terms of a text (max 3, [] when none), public, no LLM, cached 1 day
- [x] #2 iOS: WordEntry and BackendClient decode terms (optional, so old cached entries and History still decode)
- [x] #3 iOS: a backend reply with no senses but with terms is an answer, not 'not a word'; Node.js stays one word
- [x] #4 iOS and Mac: the word card shows the terms below the senses, with icon-only official site and Wikipedia buttons
- [x] #5 iOS: a bundled word gets its terms from GET /api/terms in the background; offline nothing changes
- [x] #6 Extension: decodes and shows terms in the popup
- [x] #7 Tests: backend endpoint, Swift Testing for decoding, terms-only answer and bundled terms, extension vitest
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [x] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [x] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Built: backend GET /api/terms/{text} (TermController, public read limit); iOS WordEntry.terms + Term, BackendClient terms decode + terms(forText:), WordLookup accepts terms-only entries, TranslationStore.addTermsToBundledWord, Views/Word/TermSection (icon-only safari/book buttons), used by WordCardView (iOS, Mac panel, share sheet); extension api/explain/textKind/card termSection. No mockup: developer's choice 2026-11-02 (doc-7). Tests: TermLookupTest 5 green; extension vitest 168 green, tsc clean. Swift tests written (BackendClientTests 2, WordLookupTests 2, TranslationStoreTests 2) but NOT run: Linux container, no Xcode. DoD #1 stays open until the developer runs Cmd-U.
<!-- SECTION:NOTES:END -->
