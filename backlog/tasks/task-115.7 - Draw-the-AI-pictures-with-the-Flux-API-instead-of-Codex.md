---
id: TASK-115.7
title: Draw the AI pictures with the Flux API instead of Codex
status: To Do
assignee: []
created_date: '2026-11-09 07:50'
updated_date: '2026-11-09 07:50'
labels:
  - media
  - pipeline
dependencies: []
parent_task_id: TASK-115
ordinal: 169000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Developer decision 2026-11-09: use Flux to draw the media-ai pictures instead of the Codex CLI, because Flux has an API. Codex on the ChatGPT plan stops at the plan usage limit (the VPS run stopped on 2026-11-05 and 11-06 with 2,148 bundled + 90 backend Pixabay senses left) and its logs filled the VPS disk on 2026-11-06. The scene and the blind guess stay as they are (STEYG gateway). media_ai.py already has an ImageDrawer protocol: CodexDrawer is the real one, tests use a fake. Flux costs money per picture (Codex did not), so the cost cap and the estimate must count it. Pick the Flux provider and model (for example Black Forest Labs API or a host like fal.ai/Replicate) and check the price before building.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A FluxDrawer implements ImageDrawer (prompt in, PNG/WebP bytes out) with the key from pipeline/.env (new key in .env.example and doc-11)
- [ ] #2 media-ai picks the drawer with an option (codex or flux); the VPS script uses flux and no longer needs a Codex login
- [ ] #3 The per-picture Flux price is counted in the cost cap, the dry-run estimate and media_generation.cost_usd
- [ ] #4 Rate limits and server errors are retried; a bad key or no credit stops the run (ProviderStop)
- [ ] #5 Tests with a fake Flux HTTP server; a 10-sense trial compared with the Codex pictures before the full run
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
