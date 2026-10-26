---
id: TASK-116
title: 'Web home: chip keyboard shortcuts and better suggestion ranking'
status: In Progress
assignee:
  - '@implementer'
created_date: '2026-10-25 15:36'
updated_date: '2026-10-25 15:46'
labels:
  - web
  - backend
dependencies: []
priority: medium
ordinal: 146000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
On the web home page the learner picks a recent, hot or suggested word from the keyboard, and suggestions match what they type better. Design agreed 2026-10-25: option A (inline completion, Tab, arrows) plus numbered chips (Alt+1-9).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Typing shows the top suggestion as grey inline completion in the composer; Tab accepts it into the box
- [ ] #2 Down/Up move a highlight through the chips (from the box, also when it is empty); Enter opens the highlighted chip; Esc clears the highlight; ARIA combobox/listbox roles and aria-activedescendant
- [ ] #3 Alt+1..Alt+9 opens chip N whether the box is empty or typed; chips show a small 1-9 key hint (hidden on touch screens)
- [ ] #4 The user's own recent words that match the prefix show at once from local history (no network), then server suggestions merge in after the 250 ms debounce without duplicates
- [ ] #5 GET /api/suggest ranks: exact match, then popularity (lookup counts across users, like hot words), then NGSL rank, then shorter
- [ ] #6 Suggest also finds phrases where a later word starts with the prefix ("up" finds "give up"), still under 50 ms on the server
- [ ] #7 Vitest and backend tests cover the ranking, local merge and keyboard handling; doc-24 and the matching feature doc updated
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR: https://github.com/tranphuocloc070699/saynata/pull/229. Test it: (1) empty box: chips show numbers 1-9; Alt+1 (Option+1 on Mac) opens chip 1, no symbol typed. (2) type 'giv': matching recent words first, then server list; grey completion after the caret when the top chip starts with it. (3) Tab accepts the grey text (not sent); with no grey text or caret not at end, Tab moves focus. (4) ArrowDown/ArrowUp highlight chips (also from an empty box), Enter opens the highlighted chip, Esc clears it. (5) type 'up': phrases like 'give up' appear. (6) touch device: number hints hidden. Automated: cd web && npx vitest run test/startChips.test.ts test/chipKeys.test.ts; cd backend && ./mvnw -B test -Dtest='Suggest*'.
<!-- SECTION:NOTES:END -->
