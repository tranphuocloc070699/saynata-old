---
id: TASK-119.1
title: 'Backend: term tables, alias-key lookup and terms in the word reply'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02 08:55'
updated_date: '2026-11-02 09:14'
labels:
  - backend
dependencies: []
parent_task_id: TASK-119
ordinal: 149000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
V39 term + term_alias. TermKeys.key(text). TermService.find(text) (max 3, by popularity). WordService adds terms to every answer and answers a not-a-word text that is a term alias with its terms.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 V39 creates term (wikidata_id unique, name, field, simple_definition, official_url, wikipedia_url, popularity) and term_alias (alias_key, term_id, source), unique (alias_key, term_id), index on alias_key
- [x] #2 TermKeys.key: lower case, drops dots, dashes, underscores and spaces (Nuxt.js, NuxtJS, nuxt js -> nuxtjs)
- [x] #3 Every word reply has terms (max 3, most popular first), left out of the JSON when empty; English senses are unchanged
- [x] #4 A not-a-word text with a term alias (nuxtjs) gets its terms with empty senses; Claude is never called for it
- [x] #5 Tests: key rules, a term below an English word (swift), a term-only answer (nuxtjs), no terms = no field
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Tests pass
- [x] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [x] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Built: V39 term + term_alias, term/TermKeys, TermService (limit 3 by popularity), WordResponse.terms (NON_EMPTY), Origin.TERM (cache like CACHED), WordService.withTerms/termAnswer (before not-a-word and on a phrase miss). WordController path takes digits and dots inside a word. Tests: TermLookupTest (4); full backend suite 683 green. doc-5 + doc-24 updated.
<!-- SECTION:NOTES:END -->
