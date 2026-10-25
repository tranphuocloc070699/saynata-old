---
id: TASK-83.16
title: >-
  Pipeline + backend: Codex judge for book names and not_on_list words, so tech
  terms (Vue, Nuxt, Java) get definitions
status: To Do
assignee: []
created_date: '2026-10-25 05:05'
labels: []
dependencies:
  - TASK-83.15
parent_task_id: TASK-83
priority: medium
ordinal: 126000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
books collect (TASK-83.15) found about 33.8k name and 15.9k not_on_list rows in the developer books. Most are character names and code (svidriga, getmapping, argsexception), but real tech terms are in there too (vue, nuxt, java, often in the name group because they are capitalised). The developer wants definitions for those terms but cannot read 50k rows. Codex runs free on the ChatGPT plan. Also: the backend refuses words not on the SCOWL/NGSL list before it reads the cache, so pushed tech terms are never shown yet.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 books judge pre-filters name and not_on_list rows with no LLM (drop camelCase-only words, names seen only in fiction books, fewer than 3 sightings or 1 book) and prints how many are left
- [ ] #2 books judge sends the rest to Codex in batches (about 200 per call, with the example sentence) and saves keep/drop and a short reason per row; resumable; --dry-run and --limit
- [ ] #3 The review page shows the Codex verdict and reason, has a keep/drop filter, and ticks keeps that the developer has not touched
- [ ] #4 collection push marks name-group book words needs_review like not_on_list words
- [ ] #5 Backend: GET /api/words/{word} answers a word that is not on the word list when word_lookup already has it (cache before the word-list check); a new Claude call for such a word is still refused
- [ ] #6 Tests: pipeline (pre-filter, judge parsing with a fake Codex, review tick rules, push flag) and backend (cached not-on-list word answered, uncached still rejected)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
