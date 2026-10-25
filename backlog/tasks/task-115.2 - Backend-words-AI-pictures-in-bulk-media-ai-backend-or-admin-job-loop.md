---
id: TASK-115.2
title: 'Backend words: AI pictures in bulk (media-ai --backend or admin job loop)'
status: To Do
assignee: []
created_date: '2026-10-25 15:11'
labels:
  - media
  - pipeline
  - backend
dependencies: []
parent_task_id: TASK-115
ordinal: 141000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
pipeline media-ai (TASK-82) works on bundled senses. Words that Claude wrote after launch keep their pictures in word_lookup_media, so they would stay on Pixabay. Check first whether media-ai already covers them; if not, add a mode for them. Paid passes are started by the developer, not by agents.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Written finding: does media-ai reach word_lookup_media senses? If yes, document the command
- [ ] #2 If not, a mode or command makes AI pictures for backend-word senses with the same cap, resume and meaning check as media-ai
- [ ] #3 Linking sets media_status ai_generated on word_lookup_media and keeps the old media row
- [ ] #4 Tests with fake Claude and fake Codex pass (uv run pytest tests/test_media_ai.py)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
