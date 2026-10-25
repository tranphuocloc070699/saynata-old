---
id: TASK-106.7
title: 'Backend: a line miss asks every supported language in one call'
status: In Progress
assignee:
  - '@implementer'
created_date: '2026-10-25 07:11'
updated_date: '2026-10-25 07:17'
labels: []
dependencies: []
parent_task_id: TASK-106
ordinal: 126000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Today a miss in line_translation asks the LLM only for the language the learner picked (POST /api/translate-lines and the sentence line in TASK-106.6). The developer wants (2026-10-25) one LLM call to return the line in every supported language (vi, ja, ko, zh, fr, es, de) and save them all, so the next learner in another language is answered from the cache with no new call. Together with the Codex backfill (TASK-106.5, run by the developer) every word and sentence then has every language. Decision: keep app.claude.line-prompt-version at v1, because the rules for one line do not change, only the answer shape; bumping it would make every saved and backfilled line unreachable. Clients do not change.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A miss for one language makes ONE LLM call that returns lines for all 7 non-English languages; all valid lines are saved to line_translation (source llm), the requested language is returned as before
- [ ] #2 Only languages still missing for a text are saved; an existing row is never overwritten; a missing or empty language in the answer is skipped, not an error
- [ ] #3 The sentence line (lineFor with store true) uses the same all-language call; personal text (store false) still asks only the target language and saves nothing
- [ ] #4 cachedOnly, guest 401, rate limit and budget rules are unchanged; usage is still Feature LINE and the call goes through limits/ClaudeGate
- [ ] #5 max tokens fit 20 texts x 7 languages (or the misses are split into calls that do); tests with the fake Claude cover: one call fills 7 languages, a second language is then cached with no call, partial answer, personal text
- [ ] #6 doc-5, doc-17 and doc-24 describe the all-language call; doc-7 has the decision row
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR: https://github.com/tranphuocloc070699/saynata/pull/202 (into feature/local). Test it: Goal: one line miss fills all 7 languages. Steps: run backend; signed in, POST /api/translate-lines {"targetLang":"ko","texts":["<a new text>"]}; in Postgres, line_translation has 7 rows (vi ja ko zh fr es de) for that text_hash; same text with targetLang ja -> cached true and no new claude_usage row. Personal text in a sentence still makes a one-language call and saves nothing. Automated: cd backend && ./mvnw -B test -Dtest="TranslateLines*,LineTranslation*,ClaudeService*,SentenceLanguageLine*" (116 focused pass).
<!-- SECTION:NOTES:END -->
