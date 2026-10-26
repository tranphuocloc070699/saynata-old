---
id: TASK-117
title: >-
  Backend LLM providers: DeepSeek main, Gemini fallback, Codex writes picture
  scenes
status: In Progress
assignee: []
created_date: '2026-10-26 10:33'
updated_date: '2026-10-26 10:56'
labels:
  - backend
  - llm
dependencies: []
references:
  - >-
    backend/src/main/java/com/englishtranslation/backend/claude/ClaudeService.java
  - >-
    backend/src/main/java/com/englishtranslation/backend/claude/ClaudeProperties.java
  - backend/.env.example
  - backend/docker-compose.prod.yml
documentation:
  - backlog/docs/guides/doc-11 - Deploy-to-a-VPS.md
  - backlog/docs/features/doc-24 - System-map.md
priority: high
ordinal: 147000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Sentence and word calls go through the STEYG gateway (Haiku/deepseek) with six CLAUDE_* env keys whose meaning is hard to read. A benchmark (handoff 2026-10-26) showed DeepSeek direct with thinking off is fastest: first text 0.6-0.8 s, total 1.3-1.5 s, Vietnamese quality equal to Gemini. Gemini 3.5 flash-lite is the backup when DeepSeek fails. The admin wand (AI picture scene) used Claude Sonnet; Codex CLI with the ChatGPT login is free and already draws the pictures. The developer wants the .env grouped by job so the setup is clear at a glance. Production .env lives on the VPS and is edited only by the developer; the deploy workflow never writes it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Sentence, word and line calls use DeepSeek direct with thinking disabled
- [ ] #2 When DeepSeek fails before any text is streamed, the same request is answered by Gemini; after streamed text, the error is shown as today
- [ ] #3 The admin wand writes the picture scene with Codex CLI; no Claude call remains for scenes
- [ ] #4 backend/.env.example is grouped into five sections by job and has no CLAUDE_* keys
- [ ] #5 Start-up fails with a clear message when DEEPSEEK_API_KEY is empty
- [ ] #6 backend/scripts/migrate-env.sh updates a production .env safely (backup, no values printed, idempotent) and docker-compose.prod.yml passes the new keys
- [ ] #7 doc-11 explains the production switch order; doc-24 and doc-7 are updated; check_docs.py passes
- [ ] #8 Focused backend tests pass with fake keys
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
0. Commit the open work on chore/merge-open-work first (language line in the sentence call, prompt v14): it touches ClaudeService and SentenceAnswer.
1. Decision row in doc-7: DeepSeek direct main, Gemini fallback, Codex scenes. Lost: STEYG Haiku (slow first text 3.4 s), Gemini as main (first byte up to 2.2 s, no Anthropic endpoint), Claude Sonnet for scenes (costs money).
2. Config: LlmProperties replaces ClaudeProperties, with main (DeepSeek: key, model deepseek-flash, base URL https://api.deepseek.com/anthropic default) and fallback (Gemini: key, model gemini-3.5-flash-lite). Start-up fails with a clear message when DEEPSEEK_API_KEY is empty.
3. .env.example in five sections: 1 Main LLM, 2 Fallback LLM, 3 Media (Codex), 4 LLM spending (LLM_DAILY_BUDGET_USD, PREFILL_*), 5 Server/DB/admin/sign-in/email/backup. Removed: CLAUDE_API_KEY, CLAUDE_BASE_URL, CLAUDE_AUTH_TOKEN, CLAUDE_MODEL, CLAUDE_SCENE_MODEL, CLAUDE_EFFORT, AI_SCENE_DAILY_USD. Renamed: CLAUDE_DAILY_BUDGET_USD -> LLM_DAILY_BUDGET_USD.
4. DeepSeek client: today's Anthropic SDK path (JSON in prompt) plus thinking disabled on every builder. Pricing rows app.claude.pricing.[deepseek-flash] at the peak price (0.30 in / 1.20 out per MTok, checked 2026-10-26; off-peak in a comment).
5. Gemini client: OpenAI-compatible endpoint (https://ai.google.dev/gemini-api/docs/openai), same prompts, JSON in prompt, streaming. Pricing rows for the Gemini model.
6. LlmRouter: every call through ClaudeGate as now; on a DeepSeek error or timeout, retry once on Gemini, but only when nothing has streamed to the user yet. Usage rows record the model that answered.
7. Codex scenes: the admin wand runs codex exec to write the scene (same text prompt), then draws as now. Remove the Sonnet scene call and its daily USD limit.
8. Production switch: backend/scripts/migrate-env.sh (backup, ask for missing keys with read -s, --cleanup removes old keys and renames the budget key, prints key names only, idempotent). docker-compose.prod.yml lists the new keys. Order: developer adds the new keys on the VPS -> merge feature/local to main -> auto-deploy -> developer runs --cleanup.
9. Local: update backend/.env to the new names directly.
10. Docs: doc-11 (new section 'Switching LLM keys' with the order above), doc-24 (model row, env keys), feature pages that name ClaudeService lines; python3 scripts/check_docs.py.
11. Tests (fake keys, no real calls): thinking disabled is sent; fallback fires on DeepSeek error and not after the first streamed text; start-up check; Codex scene runner with a fake command. Run ./mvnw -B test -Dtest='Llm*,ClaudeService*,ClaudeGate*,AiPicture*'.
12. PR into feature/local with a Test it card (run the backend locally with the new .env, explain a sentence, kill the DeepSeek key to see Gemini answer, use the wand).
Out of scope: renaming the claude package and ClaudeGate (own small PR later); pipeline llm.py.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Code done on chore/task-117-llm-providers: LlmProperties/LlmConfig (start-up fails without DEEPSEEK_API_KEY), GeminiClient fallback inside ClaudeService (not a separate LlmRouter class), thinking off on every call, CodexSceneWriter replaces the Sonnet scene call, .env.example in 5 sections, docker-compose.prod.yml, scripts/migrate-env.sh, doc-4/7/11/15/24. Focused tests passed before the last full run; the 3 PrefillRunnerTest failures were fixed by pinning app.claude.model=claude-haiku-5-5 in test config, NOT re-run. Gemini price row missing (counted at highest price). Admin page still shows scene USD as 0.
<!-- SECTION:NOTES:END -->
