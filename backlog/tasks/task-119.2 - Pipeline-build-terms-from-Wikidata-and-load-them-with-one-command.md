---
id: TASK-119.2
title: 'Pipeline: build terms from Wikidata and load them with one command'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02 08:55'
updated_date: '2026-11-02 09:14'
labels:
  - pipeline
dependencies: []
parent_task_id: TASK-119
ordinal: 150000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
exports/terms/build_terms.py reads a seed list (exports/terms/seeds.txt, one name or Q-id per line), asks the Wikidata API (no LLM) for label, description, aliases, official website P856, enwiki link and sitelink count, adds rule aliases (nuxtjs -> nuxt), and writes terms.tsv, term_aliases.tsv and report.md with collisions. import_terms.sh loads both files on the VPS in one transaction.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 build_terms.py writes terms.tsv and term_aliases.tsv from the seeds, resumable from a local JSON cache, with --limit
- [x] #2 Aliases: Wikidata label and aliases, rule alias without a js suffix; aliases of 2 characters or fewer are kept only from Wikidata
- [x] #3 report.md lists aliases that are English words (shown below the word) and aliases shared by several terms
- [x] #4 import_terms.sh replaces term and term_alias on the VPS in one transaction
- [x] #5 Tests for key and alias rules and for parsing a Wikidata entity
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Tests pass
- [x] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [x] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Built: pipeline/src/pipeline/terms.py (python -m pipeline.terms), exports/terms/seeds.txt (about 80 software, psychology and philosophy terms; 'Name | hint' for names with several meanings), import_terms.sh (scp, docker cp, one transaction, re-run safe). Tests: tests/test_terms.py (9). Import SQL tested twice on a local Postgres 16. Real Wikidata run NOT done here: the container's IP was rate limited by Wikimedia; the developer runs it on the Mac (free).
<!-- SECTION:NOTES:END -->
