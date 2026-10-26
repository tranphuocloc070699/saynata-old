# 11. Building with AI services (LLM APIs and CLIs)

This is about the LLM features **inside your app** (like Saynata's explanations). For AI that writes
your code, see doc 01.

## One door

All model calls go through **one** wrapper per app: `python/src/app/llm.py` (`LLM.ask`) in the kit, and
`limits/ClaudeGate` + `claude/` in Saynata. The wrapper owns:

| Concern | How (kit's `llm.py`) |
|---|---|
| Timeouts | Client `timeout=` (seconds in Python, **milliseconds** in TypeScript) |
| Retries | The SDK retries 408/409/429/5xx with backoff (`max_retries`). Do not retry 400/401: they will not fix themselves |
| Budget | Spend is counted per run. `BudgetExceeded` is raised before a call that would go over |
| Cost log | Each call logs prompt, version, model, tokens in/out/cache, `cost_usd`, duration, request id |
| Prompt versions | `Prompt(name, version, system)`. Change the text → bump the version (also in logs and caches) |
| Structured output | `client.beta.messages.parse(output_format=PydanticModel)` → a validated object. No regex on model text |
| Caching | `cache_control` on the stable system prompt; the changing input comes after it |
| Safety declines | `stop_reason == "refusal"` → `LLMRefused`; server-side `fallbacks="default"` retries on a fallback model |
| Truncation | `stop_reason == "max_tokens"` → `LLMTruncated` (never use half a JSON) |
| Tests | A fake client. **Tests never call the real API** |

## Cache answers, not only prompts

Saynata's best decision: a **shared, cache-first database** for results (one word explained once, used by
all users). Key the cache on `(input, prompt_version, model)`, so a prompt change refreshes the results
on its own. This cuts cost by a lot and makes the app fast.

## Prompts are code

- Prompts live in the repo, next to the code that uses them, with a version number. They are reviewed in PRs.
- Ask for the important field first in the output schema (Saynata: explanation first, translation last).
- Put user input inside tags (`<text>…</text>`) and treat it as data. That makes prompt injection harder.
- Keep the system prompt stable (no dates or ids in it), or caching stops working.

## Evals: how you know a prompt change helped

1. Collect 20-50 real inputs (with any personal data removed), including hard ones.
2. Write what "good" means: exact checks (JSON valid, word count, has field X) and, where needed, an LLM judge with a rubric.
3. Run the old and the new prompt on the same set. Compare the scores **and** the cost.
4. Keep the set in the repo (`evals/`). Run it before every prompt version bump.
   Start with a small script. Tools like promptfoo or Braintrust can come later.

## Cost control

- Pick the model per job: cheap model (Haiku-class) for classification and short extraction, a stronger model
  for explanation and reasoning. Measure before you downgrade.
- Batch API for offline jobs (about 50% cheaper). Prompt caching for repeated long prefixes.
- Set a monthly spend limit in the provider console **and** per-user limits in the app (Saynata `limits/`).
- Keep `max_tokens` tight for short outputs, and generous for long ones (or stream them).

## AI CLIs and agents in your tooling

- `claude -p "..."` (headless Claude Code), `codex exec`, and `gemini` work in scripts and CI. Give them
  **read-only** tools unless the job must write files, and pin the model.
- GitHub: the Claude Code Action can review PRs. Treat its findings as suggestions, and you decide.
- MCP servers give agents access to Sentry, Postgres, and GitHub. Use read-only database credentials for them.
- Never give an agent production credentials. Give it a staging database and logs without personal data.

## Real examples

- Anthropic docs: *Structured outputs*, *Prompt caching*, *Errors and retries*, *Building evals*.
- Hamel Husain, *Your AI product needs evals* (how to start small).
- This repo: `backend/.../limits/ClaudeGate`, `app.claude.*-prompt-version` in `application.properties`,
  and `pipeline/src/pipeline/llm.py`.
