---
id: TASK-106.8
title: Word language row shows the headword translated per sense
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-25 07:31'
updated_date: '2026-10-25 07:46'
labels: []
dependencies: []
parent_task_id: TASK-106
ordinal: 127000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Developer-approved design (mockup chosen 2026-10-25): when the collapsed target-language row of a WORD card opens, show the headword translated into the target language in bold first (programmer, Japanese -> **プログラマー**), then the existing definition line below in secondary color. Sentence cards do not change. The headword is translated PER SENSE (bank -> 銀行 for money, 土手 for river), so POST /api/translate-lines takes an optional headwords list (same order as texts) and each line answers an optional translated headword. Decision: line_translation v1 definition lines stay as they are (Codex backfill TASK-106.5 and TASK-106.7 rely on them); the headword is saved as its own line_translation row, keyed by sha256 of headword + sense text, with its own prompt version (app.claude.headword-prompt-version, stored as prompt_version headword-v1). One LLM miss still fills all 7 languages (lines and headwords).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 POST /api/translate-lines accepts optional headwords (same length as texts, entries may be null); each line has a headword field (null when not asked or not saved); sentence requests and old clients work unchanged
- [ ] #2 Headword rows are saved in line_translation per (headword, sense text, language) with prompt version headword-v1; v1 definition lines are never changed or made unreachable
- [ ] #3 A miss (line or headword) is ONE LLM call through limits/ClaudeGate that returns lines and headwords for all 7 languages; only missing rows are saved; cachedOnly never calls the LLM
- [ ] #4 iOS/Mac word cards (full, compact, Quick explain), web and extension show the bold headword above the line when the row opens; without a headword only the line shows; Vietnamese dictionary fallback unchanged; sentence cards unchanged
- [ ] #5 Focused tests cover backend (fake Claude), iOS LineTranslating/row model, web and extension
- [ ] #6 doc-5, doc-23, doc-19, doc-24 and doc-7 updated; the task says whether pipeline lines needs a headword pass
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Backend: TranslateLinesRequest.headwords, Line.headword, WordLinesAnswer + WORD_LINES_PROMPT (LINE_RULES reused), headword rows in line_translation (prompt_version headword-v1), tests.
2. iOS/Mac: LineTranslating returns line + headword; TargetLanguageRowContent shows bold headword above line.
3. Web lines.ts + WordCard, extension lines.ts + card.ts.
4. Docs, check_docs, PR into feature/local.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Pipeline: pipeline lines has no headword pass; it is a follow-up task (needs its own collect, prompt, check and push). Until then a backfilled word makes one LLM call (Feature LINE) the first time a signed-in learner opens its row, which also fills the headwords for all 7 languages. Guests (cachedOnly) see only the line.
<!-- SECTION:NOTES:END -->
