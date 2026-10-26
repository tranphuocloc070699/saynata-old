# __APP_NAME__

__ONE_LINE_PITCH__

| Part | Stack | Folder |
|---|---|---|
<!-- new-project.sh fills this table from the stacks you picked -->
__PARTS_TABLE__

## How we work: the human reads every line

The developer reviews every line an agent writes. Your job is to make that review easy.

1. **Plan before code.** For anything bigger than a one-line fix, write a short plan (files to touch, what
   changes, how to test) and wait for "go". Use the `/step` skill.
2. **Small steps.** One step = one idea, at most ~200 changed lines. A hook blocks edits when the uncommitted
   diff passes `DIFF_BUDGET` (default 300 lines). When it fires: stop, show the diff, let the human commit.
3. **Explain the diff.** After each step, run `/explain-diff`: every file, why it changed, what to look at.
4. **No surprise changes.** Do not reformat, rename, or "clean up" code outside the step. Put ideas in a
   "Follow-ups" list instead.
5. **No new dependency** without asking first (name, why, size, licence, last release date).
6. **Never** read `.env` files, print secrets, force-push, push to `main`, or skip/disable a test.

## Commands

| What | Command |
|---|---|
| Start local services (Postgres…) | `make up` |
| Run everything's checks (lint, types, tests) | `make check` |
| Check one part | `make check-<part>` (for example `make check-backend`) |
| Tidy merged branches | `scripts/cleanup-branches.sh` |
| Merge an approved PR when CI is green | `scripts/merge-when-green.sh <PR>` |

Run only the checks of the part you changed while working. CI runs everything on PRs into `main`.

## Conventions (all parts)

- **Folders by feature, not by layer** (`notes/`, `billing/`), each with its own API, logic, data and tests.
- **Config from env only.** Every key is in `.env.example` with a comment. The app fails at start if a key is
  missing (validated config object), never later at run time.
- **Errors**: backend returns RFC 9457 Problem Details with a stable `code`; clients switch on `code`, never on text.
- **Logs**: structured (JSON in prod), one event per line, with `request_id`. No secrets or personal data.
- **Database**: schema changes only as a new migration file. Never edit a migration that is merged.
- **Tests**: every behaviour change comes with a test. Name tests after the behaviour, not the method.
- **AI calls** (LLM APIs): one wrapper per app (timeouts, retries, budget, prompt version, logging). Tests
  never call a real model. See `docs/` in the starter kit: `11-ai-services.md`.
- **Commits**: Conventional Commits (`feat(notes): add search`). Branches: `feat/<what>`, `fix/<what>`,
  deleted after merge. One branch = one PR = one reviewable idea.
- **Decisions**: a decision that is hard to undo gets an ADR in `docs/adr/` (`/adr` skill), the same day.

## Stack rules

<!-- new-project.sh appends the rules of each picked stack here -->
__STACK_RULES__
