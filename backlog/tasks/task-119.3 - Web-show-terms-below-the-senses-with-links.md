---
id: TASK-119.3
title: 'Web: show terms below the senses with links'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02 08:55'
updated_date: '2026-11-02 09:14'
labels:
  - web
dependencies: []
parent_task_id: TASK-119
ordinal: 151000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The word result shows an 'Also a name' section: name, field, simple definition, official site and Wikipedia links. A term-only reply (nuxtjs) shows the term instead of the not-a-word error.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Word result shows terms below the senses, links open in a new tab (rel noopener)
- [x] #2 A reply with no senses but with terms shows the terms, not the not-a-word error
- [x] #3 Vitest tests for both cases
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Tests pass
- [x] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [x] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Built: api.ts Term + WordResponse.terms, explain.ts shows a reply with terms and no senses as a word card, textKind.ts sends dotted words (node.js) to the word API, WordCard TermList ('Also a name' / 'A name', Official site and Wikipedia links, new tab, noopener). Tests: textKind + explain (vitest), full web suite 185 green. Not checked in a browser (no agent UI testing by default).
<!-- SECTION:NOTES:END -->
