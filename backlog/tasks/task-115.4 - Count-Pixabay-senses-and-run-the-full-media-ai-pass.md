---
id: TASK-115.4
title: Count Pixabay senses and run the full media-ai pass
status: To Do
assignee: []
created_date: 2026-10-25 15:11
updated_date: '2026-11-04T08:29:00Z'
labels:
  - media
  - pipeline
dependencies:
  - TASK-84
parent_task_id: TASK-115
ordinal: 143000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Paid and slow (about 26 hours, Claude about 34 USD, Codex on the ChatGPT plan). The developer starts it; this task tracks it. It continues TASK-84, so use TASK-84 for the run itself and record the numbers here. Keep the Mac awake.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Count of senses with media.source = pixabay recorded in the task notes before the run
- [ ] #2 media-ai --all run finished for bundled and backend words (stopped at the cap and resumed until done)
- [ ] #3 Failed senses listed in data/out/media-ai.html
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-11-04: one script runs the whole pass: pipeline/scripts/replace-pixabay-pictures.sh count (record numbers here), then draw (paid, about $34 Claude + Codex, about 26 h; resumable), then ship (TASK-115.5).

2026-11-04 count before the run (pipeline/.env DATABASE_URL): bundled words 2577, backend words 90, total 2667 senses with a Pixabay picture.

2026-11-04: developer chose the VPS + gateway route (doc-7): pipeline/scripts/media-ai-on-vps.sh setup (checks the guess model reads pictures, dry-run estimate), start (background on the VPS), status, stop, link (copy + link on the server, export on the Mac). Not run yet.

2026-11-04: STEYG keys in a temporary pipeline/.env.steyg (ANTHROPIC_* form). Tested here with a fake STEYG server and fake Codex: key mapping, setup (picture check passes on 'red', stops on 'blue'), start/status/stop. Fixed: media-ai asked for ANTHROPIC_API_KEY even through a gateway (cli.py, new test). Not tested: the real VPS, real STEYG, real Postgres.
<!-- SECTION:NOTES:END -->
