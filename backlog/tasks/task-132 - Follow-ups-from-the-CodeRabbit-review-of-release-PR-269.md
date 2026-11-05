---
id: TASK-132
title: 'Follow-ups from the CodeRabbit review of release PR #269'
status: To Do
assignee: []
created_date: '2026-11-05T08:32:00Z'
labels: []
dependencies: []
priority: high
ordinal: 169000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
CodeRabbit findings on PR #269 (2026-11-05) that were not fixed before the release: (1) SECURITY: extension/src/shared/sentry.ts:45 may send sensitive data (CWE-200), check the scrub before setting the extension DSN; (2) extension/src/background/index.ts:87: explain() catches unexpected errors without reporting them to Sentry; (3) backend ApiExceptionHandler.handleClaudeError: Claude 502s never reach Sentry; (4) LineTranslationService: an empty fast-call line or headword is skipped by the background fill (askClaude alreadySaved), so it stays uncached; fix or document in doc-5; (5) doc-23 sendCode and verify links (159, 178) and the doc-5 Mermaid flow.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The extension Sentry scrub is checked and sends no selected text, tokens or response bodies
- [ ] #2 Unexpected explain() errors and Claude 502s are reported to Sentry
- [ ] #3 An empty fast-call line is saved by the background fill, or doc-5 names the exception; a regression test covers it
- [ ] #4 doc-23 links and the doc-5 diagram match the code
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
