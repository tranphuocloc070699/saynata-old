---
id: TASK-128.1
title: Event list and tool setup (Sentry + PostHog projects, keys)
status: To Do
assignee: []
created_date: 2026-11-04 10:35
updated_date: '2026-11-04T12:01:00Z'
labels:
  - analytics
dependencies: []
parent_task_id: TASK-128
ordinal: 160000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
One source of truth for event names and properties, so iOS, web and the extension never drift (DRY). The developer creates the free Sentry and PostHog accounts and gives the keys; keys go in env/config, never in git.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 docs/analytics/events.md lists about 12 events with properties, for example lookup_done {kind: word|sentence, source: app|share|intent|panel|extension, cache_hit}, listen_tapped, speak_scored {score}, language_row_opened {lang}, item_liked, quick_explain_used, signed_in
- [x] #2 The doc says which question each event answers (adoption, repeat use, explicit like) and lists the PostHog insights to build, including the language-row open rate
- [x] #3 The doc states the privacy rule: never send looked-up text, only kind, source, length bucket and cache hit
- [x] #4 Sentry projects exist for ios, web, extension, backend and a PostHog project exists; new keys are in .env.example files and doc-24
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Sentry plugin installed 2026-11-04 (npx @sentry/agent-plugin install, org tran-phuoc-loc, run code 429c4b8d7d; also added to Codex). After restarting Claude Code, use the Sentry plugin to create 4 projects: saynata-ios (Apple iOS, also used by Mac), saynata-web (Next.js), saynata-extension (Browser JavaScript), saynata-backend (Spring Boot). Put the DSNs in .env.example files and doc-24, never real keys in git. PostHog account still needed.

2026-11-04: create_project via the Sentry plugin fails with 403 (members cannot create projects), so the developer creates projects by hand. Done: saynata-ios, saynata-web, saynata-extension exist; DSNs are in doc-24 (section Error reporting) and in web/.env.local and extension/.env.local. SENTRY_DSN placeholder in backend/.env.example; new web/.env.example (NEXT_PUBLIC_SENTRY_DSN) and extension/.env.example (VITE_SENTRY_DSN). Web SDK set up in TASK-128.4 (verified: server error SAYNATA-WEB-1 reached Sentry without the ?q= text) and extension SDK in TASK-128.5 (build and tests pass; event not verified, needs the extension loaded in Chrome). Left: developer creates saynata-backend (Spring Boot) and the PostHog project; docs/analytics/events.md (AC 1-3); GitHub variable SENTRY_DSN_WEB and secret SENTRY_AUTH_TOKEN.

2026-11-04: saynata-backend created by the developer; all 4 Sentry projects exist and their DSNs are in doc-24. Left in this task: PostHog project and docs/analytics/events.md (AC 1-3).

2026-11-04: PostHog project created (US, project 709641, Product Analytics only, Session Replay off); key and host in doc-24 (section Usage tracking). Left: docs/analytics/events.md (AC 1-3).

2026-11-04: docs/analytics/events.md written (AC 1-3): 12 events + speak_scored reserved (speech scoring not built yet), super properties (platform, app_version, signed_in), source values per platform, length bucket, privacy rule, PostHog insights for TASK-128.6 including the language-row open rate (language_row_opened / lookup_done with row_start=closed).

2026-11-04: AC 4 checked: the 4 Sentry projects and the PostHog project exist, keys in doc-24 and the .env.example files (see notes above). Left for the developer: GitHub variable SENTRY_DSN_WEB and secret SENTRY_AUTH_TOKEN (web deploy, TASK-128.4).
<!-- SECTION:NOTES:END -->
