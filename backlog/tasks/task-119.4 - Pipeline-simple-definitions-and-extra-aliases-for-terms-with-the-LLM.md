---
id: TASK-119.4
title: 'Pipeline: simple definitions and extra aliases for terms with the LLM'
status: To Do
assignee: []
created_date: '2026-11-02 08:55'
labels:
  - pipeline
dependencies: []
parent_task_id: TASK-119
ordinal: 152000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Rewrite each Wikidata description plus the first Wikipedia lines into one simple B1 sentence (SimpleWords rules), and suggest extra aliases (RN, TS, CBT). Grounded in the given facts; aliases that are English words or shared go to review. Paid pass: the developer starts it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Simple definition per term from the given facts only, checked with the simple word rules
- [ ] #2 Suggested aliases saved with source=llm and needs_review when short, an English word or shared
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
