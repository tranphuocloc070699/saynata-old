---
id: TASK-118
title: 'Backend: word forms for backend words (contaminated finds contaminate)'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02T06:51:00Z'
updated_date: '2026-11-02T06:52:00Z'
labels:
  - backend
dependencies: []
priority: medium
type: task
ordinal: 147000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Today only the ~2,750 bundled words have forms (dictionary_form, iOS forms table). GET /api/words/{word} never resolves a form: 'contaminated' gets its own Claude entry and the web app and extension miss 'ran' -> 'run'. Add a word_form table (form -> lemma, form_type), filled from exports/word-forms/word_forms.tsv (lemminflect, no LLM), and resolve forms in WordService before calling Claude. The reply gets matchedForm {text, type}, the shape iOS already shows.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 V38 creates word_form (form, lemma, form_type, kind), unique (form, lemma), index on form
- [x] #2 A form of a bundled word (dictionary_form) or of a cached word (word_form) is answered from the lemma's entry with matchedForm, without Claude
- [x] #3 An exact entry wins: a word that is bundled or cached itself is answered as before (glasses, injected)
- [x] #4 A form whose lemma has no entry falls through to the old flow; a phrase form (gave up) is answered from the cached phrase
- [ ] #5 iOS decodes matchedForm from the backend reply; the import command is documented
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. V38 word_form table. 2. WordForms lookup (dictionary_form first, then word_form). 3. WordService: form answer after the exact cache miss, for not-on-list words, and for phrase misses; matchedForm on WordResponse. 4. iOS BackendClient decodes matchedForm. 5. Tests (WordFormLookupTest, BackendClientTests). 6. doc-5 + doc-24, import command.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Import command tested on a local Postgres 16: 43,278 rows, re-run safe (TRUNCATE + \copy in one transaction). iOS test added but not run here (Linux container, no Xcode).

Backend: full suite 669 tests green (mvn -B test). AC 5: iOS decoding + 2 Swift tests written, not run here; needs Xcode (BackendClientTests).
<!-- SECTION:NOTES:END -->
