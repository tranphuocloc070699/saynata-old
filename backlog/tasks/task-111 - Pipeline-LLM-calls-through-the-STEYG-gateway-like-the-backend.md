---
id: TASK-111
title: 'Pipeline: LLM calls through the STEYG gateway, like the backend'
status: In Progress
assignee: []
created_date: '2026-10-24 14:50'
updated_date: '2026-10-24 14:55'
labels:
  - pipeline
dependencies: []
ordinal: 122000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Since 2026-10-24 the developer does not want to use an Anthropic API key. The backend already talks to an Anthropic-compatible gateway (STEYG) with CLAUDE_BASE_URL and CLAUDE_AUTH_TOKEN; the pipeline still needed ANTHROPIC_API_KEY for every paid step (generate, examples, usage, topics judge, media-check, media-ai, collection compare). STEYG ignores structured outputs, so the schema has to go in the prompt, as in the backend (doc-11). The Message Batches API has no gateway version.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 With CLAUDE_BASE_URL and CLAUDE_AUTH_TOKEN set, every pipeline LLM step calls the gateway with a Bearer token
- [ ] #2 The model is the step env (CLAUDE_JUDGE_MODEL, CLAUDE_SCENE_MODEL, CLAUDE_GUESS_MODEL, CLAUDE_CHECK_MODEL), else CLAUDE_MODEL, else deepseek-v4.1-flash
- [ ] #3 Through the gateway the JSON Schema is in the system prompt and the answer is parsed from the text, with one more try on bad JSON
- [ ] #4 Without CLAUDE_BASE_URL the Anthropic API behaviour is unchanged
- [ ] #5 collection batch submit/collect stops with a clear message in gateway mode
- [ ] #6 Costs use the deepseek-v4.1-flash price; tests use a fake HTTP server and make no real call
- [ ] #7 pipeline/.env.example, doc-6, doc-15, doc-18, doc-7 and CLAUDE.md describe the gateway
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add pipeline/src/pipeline/llm.py: one cached client (gateway with Bearer token when CLAUDE_BASE_URL is set, else Anthropic), model order (step env, CLAUDE_MODEL, deepseek-v4.1-flash), PRICES, parse() with schema in the prompt + one retry, create().
2. Move generate, usage, examples, topics, media_check, media_ai, collection, collection_batch to llm.
3. Block collection batch submit/collect in gateway mode.
4. Tests with a fake HTTP server (test_llm.py), autouse fixture that clears gateway envs.
5. .env.example, doc-6, doc-15, doc-18, doc-7 row, CLAUDE.md.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Built llm.py and moved every Claude call in the pipeline to it. Gateway mode: no output_config/effort, JSON Schema appended to the system prompt (same words as backend ClaudeService.jsonInstruction), JSON read from first { to last }, 2 tries with tokens summed; refusal fails at once. Unknown model priced at the highest listed price. collection batch submit/collect exit with a message through the gateway (status still works). Tests: uv run pytest -> 305 passed, 51 skipped (Postgres). No paid call made.
<!-- SECTION:NOTES:END -->
