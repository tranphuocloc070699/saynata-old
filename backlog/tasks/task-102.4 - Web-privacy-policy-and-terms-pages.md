---
id: TASK-102.4
title: Web privacy policy and terms pages
status: In Progress
assignee:
  - '@claude'
created_date: 2026-10-24 17:30
updated_date: '2026-11-04T15:31:00Z'
labels: []
dependencies: []
parent_task_id: TASK-102
ordinal: 123000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Google brand verification (needed to show the Saynata logo in the Google sign-in popup on web and iOS) asks for a working privacy policy URL and terms URL on saynata.com. The web app has only the homepage, so these pages do not exist yet. They also help the App Store review and Sign in with Apple.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `https://saynata.com/privacy` shows a privacy policy: what data Saynata keeps (email, sign-in identities, history and liked items, Claude usage), why, and how to delete the account
- [x] #2 `https://saynata.com/terms` shows the terms of use
- [x] #3 Both pages are linked from the homepage footer and from the sign-in page
- [x] #4 Vitest covers that both routes render
- [x] #5 doc-23 lists the two routes
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Shared LegalPage layout (web/src/components/legal/LegalPage.tsx)
2. /privacy: server, DeepSeek + Gemini, Resend, Google/Apple sign-in, PostHog (never the looked-up text, docs/analytics/events.md rule), Sentry, what we keep, how long, delete account
3. /terms: plain terms of use
4. Links: homepage footer + sign-in/sign-up note
5. web/test/legal.test.ts renders both routes
6. doc-23 routes
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Pages /privacy and /terms (LegalPage layout), footer links on home and legal pages, Terms/Privacy links under the sign-in form, web/test/legal.test.ts (6 pass), doc-23 section. Contact address CONTACT_EMAIL = privacy@saynata.com: the mailbox must exist before Google verification. PostHog 1 year / Sentry 90 days are the plan retention limits; check them in each dashboard.
<!-- SECTION:NOTES:END -->
