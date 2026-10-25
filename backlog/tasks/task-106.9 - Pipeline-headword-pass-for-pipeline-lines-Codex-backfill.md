---
id: TASK-106.9
title: 'Pipeline: headword pass for pipeline lines (Codex backfill)'
status: To Do
assignee: []
created_date: '2026-10-25 07:46'
labels: []
dependencies: []
parent_task_id: TASK-106
ordinal: 128000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-106.8 added the headword of each word sense to the language row: rows in line_translation with prompt_version headword-v<app.claude.headword-prompt-version>, text_hash = sha256 of 'headword|<normalized headword>|<normalized sense text>' (CacheKeys.key), text = the headword. pipeline lines (pipeline/src/pipeline/lines.py) fills only the definition lines (v1), so every backfilled word still makes one LLM call the first time a signed-in learner opens its row. Add a headword pass: collect (headword, sense text) pairs for bundled and backend words, write the headword per sense and language with Codex using the headword part of WORD_LINES_PROMPT (ClaudeService), check, push as source codex, never over an existing row. Not built in TASK-106.8 because it needs its own collect, prompt, check and push steps.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 pipeline lines can collect, write, check and push headword rows with the same hash and prompt_version as the backend
- [ ] #2 Tests in pipeline/tests cover the hash (matches the Java CacheKeys.key), the prompt and push never overwriting
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
