---
id: TASK-115.4
title: Count Pixabay senses and run the full media-ai pass
status: To Do
assignee: []
created_date: '2026-10-25 15:11'
updated_date: '2026-11-09 07:51'
labels:
  - media
  - pipeline
dependencies:
  - TASK-84
  - TASK-115.7
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

2026-11-04: full run started on the VPS (pipeline/scripts/media-ai-on-vps.sh, STEYG gateway, pid 1256133, log /root/saynata-pipeline/pipeline/data/out/media-ai-run.log). Bundled words first, then backend words. Next: status until FINISHED, then 'link'.

2026-11-04 09:11: the first VPS run failed from sense 63 on: Codex 401 'refresh token was already used' (the pipeline shared the admin's Codex login). About $0.45 of scenes wasted; the errored senses are tried again on the next run. Fix: own login ~/.codex-pipeline with device-code sign-in in setup, a real Codex call before the run, and media-ai stops on a Codex login error (test added). The admin's Codex login may need a new sign-in too.

2026-11-09 (production DB, read-only): the run DOES pick the Pixabay senses. The '91 senses are left' line was the backend pass: after the bundled pass stopped at the Codex plan limit, media-ai still exited 0, so the backend pass ran and printed last. Real numbers: bundled 2,177 Pixabay = 2,147 never tried + 1 unfinished (both pending), 22 failed 3 tries, 3 method none, 4 passed but file lost. The run also picks 600 senses that already have an older (non ai-v1) AI picture: 2,748 bundled pending in all. Backend: 89 never tried + 1 none. Measured Claude cost $0.0101 per sense (622 senses, $6.29), so Pixabay only (2,148 + 89 + 7 lost) is about $23; with the 600 old AI senses about $29. Codex: about 1.3 pictures per sense on the ChatGPT plan. Fixes: media-ai exits 3 on any early stop and the VPS script then stops (no backend pass); --batch 100 --clean-codex-home deletes each call's Codex session files and every Codex log between batches; --min-free-gb 2 stops new senses below 2 GB free (start checks it too); a passed unlinked try whose file is neither in data/media nor on the server moves to prompt version ai-v1-lost and is drawn again (7 rows: right_1, right_2, back_1, here_1, here_2, child_1, call_1); status shows the bundled and backend 'left' lines and free disk; ESTIMATE_PER_SENSE 0.03 -> 0.012. Not used: codex exec --ephemeral (0.163.0 has it, but untested whether pictures still land in generated_images). Tested with fakes and a throwaway Postgres; not run on the VPS yet.

2026-11-09: developer decision: draw with the Flux API instead of Codex (Flux has an API; Codex stops at the ChatGPT plan limit and filled the disk). The full run waits for TASK-115.7 (FluxDrawer). Scene and guess models stay on STEYG.
<!-- SECTION:NOTES:END -->
