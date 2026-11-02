---
id: TASK-119.5
title: 'Backend: look up an unknown term on Wikidata at request time'
status: To Do
assignee: []
created_date: '2026-11-02 08:55'
labels:
  - backend
dependencies: []
parent_task_id: TASK-119
ordinal: 153000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When a text is not a word, not cached and not a term, search Wikidata (wbsearchentities) with a timeout; keep only an exact label or alias match, save the term, and answer it. Gate and budget apply when the LLM writes the simple definition.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Exact label or alias match only; timeouts and errors fall back to the not-a-word reply
- [ ] #2 Saved term is answered from the DB next time
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
