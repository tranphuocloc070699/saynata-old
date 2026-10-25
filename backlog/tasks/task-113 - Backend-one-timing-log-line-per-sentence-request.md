---
id: TASK-113
title: 'Backend: one timing log line per sentence request'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-25 07:49'
updated_date: '2026-10-25 07:55'
labels:
  - backend
dependencies: []
ordinal: 128000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Some sentences still take a long time to appear, and we cannot tell which step is slow: the network, the cache lookup, the gate, the LLM (first token or full answer), the second language-line call, or the DB save. The backend logs no step times today. One log line per sentence request lets the developer grep the VPS logs for the slow real requests.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every sentence request (plain and streaming) logs one INFO line with: cache hit or miss, gate ms, LLM first-token ms (streaming), LLM done ms, line call ms, save ms, total ms
- [ ] #2 Steps that did not run are shown as '-' or left out, not as 0
- [ ] #3 The line has no sentence text (only a short key prefix), so personal text is not written to logs
- [ ] #4 A test checks the line is logged for a cache miss and a cache hit
- [ ] #5 doc-4 says where the line is and how to read it
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. SentenceTiming class: times named steps, first token, one INFO line, no text.
2. Wrap every step in TranslationService.translate; log in finally.
3. Unit test with a fake clock; output-capture test for miss and hit.
4. doc-4 section.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added SentenceTiming and wired it into TranslationService (lookup, gate, llm, llm_first_token for streaming, save, line, total, result). 61 focused tests pass. doc-4 has a 'Timing log' section.
<!-- SECTION:NOTES:END -->
