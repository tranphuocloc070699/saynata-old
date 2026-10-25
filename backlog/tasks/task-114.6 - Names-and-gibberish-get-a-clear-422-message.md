---
id: TASK-114.6
title: Names and gibberish get a clear 422 message
status: To Do
assignee: []
created_date: '2026-10-25 12:34'
updated_date: '2026-10-25 12:38'
labels: []
dependencies: []
parent_task_id: TASK-114
ordinal: 138000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A person's name alone gets its own 422 (code a_name); gibberish and code get not_a_word. Messages are B1 English, shown by every client.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Backend: sentence prompt v13 adds sourceLang 'name'. NotEnglishException has notAWord()/aName() with codes not_a_word / a_name, shown in the 422 ProblemDetail and in the stream error event. iOS PromptVersions.sentence = v13. No requeue migration (v12 had none). Tests: ClaudeService*Test, TranslationControllerTest, TranslationStreamTest pass. PR #222. Real-text check is in the Test it card.
<!-- SECTION:NOTES:END -->
