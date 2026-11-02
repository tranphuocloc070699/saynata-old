---
id: TASK-119
title: >-
  Terms: named things (Node.js, Nuxt, Stoicism) with a simple definition and an
  official link
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02 08:55'
updated_date: '2026-11-02 09:14'
labels:
  - backend
  - web
  - pipeline
dependencies: []
priority: medium
type: feature
ordinal: 148000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Today GET /api/words/{word} answers 'nuxtjs' with no senses (not on the English word list) and the web shows 'This does not look like a word'. Add terms: named things from any field (software, psychology, philosophy...) with a short simple definition, an official site and a Wikipedia link, grounded in Wikidata (CC0). A term never replaces an English word: the reply gets an optional 'terms' list (at most 3) shown below the senses ('swift' = fast, plus Swift the language). Aliases are matched by a key: lower case without '.', '-', '_' and spaces, so Nuxt.js, NuxtJS, nuxt js and nuxtjs are one key. The link always comes from Wikidata (P856), never from an LLM.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A word reply carries terms [{name, field, simpleDefinition, officialUrl, wikipediaUrl}] (at most 3, left out when empty) for every origin
- [x] #2 A text that is not an English word but is a term alias (nuxtjs) is answered with its terms instead of an empty not-a-word reply
- [x] #3 Terms are filled offline from Wikidata by a pipeline script and loaded with one command; collisions with English words and with other terms are reported
- [x] #4 The web app shows the terms below the senses with the official site and Wikipedia links
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
119.1-119.3 built on branch feature/task-119-terms. Left: 119.4 (LLM simple definitions and aliases, paid, developer starts), 119.5 (live Wikidata lookup), 119.6 (iOS and extension, mockup first).
<!-- SECTION:NOTES:END -->
