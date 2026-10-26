# 01. Working with AI agents when you read every line

Saynata taught three lessons:

1. **AI writes faster than one person can review.** The repo has 200+ branches, and many of them were
   never cleaned up. Speed was never the problem. The problem was that review could not keep up.
2. **Rules in a text file are only wishes. Hooks and CI enforce them.** `guard-git-push.sh` worked
   every time. Sentences in CLAUDE.md like "keep the doc updated" were often skipped.
3. **Agents write old APIs.** While building this kit, the agent wrote `sendDefaultPii` (removed in
   Sentry 11) and `onUnhandledRequest` (renamed in MSW 3). The type checker caught both. Strict types
   and real builds are your safety net, so turn them on from day one.

## The loop: one step, one review, one commit

```
 you: task ──► agent: plan (files, size, tests) ──► you: "go" / change it
                                                        │
 you: commit ◄── you: read the diff ◄── agent: /explain-diff ◄── agent: code + tests + checks
```

| Rule | Why | Where it is enforced |
|---|---|---|
| Plan first, wait for "go" | You agree on the shape before 300 lines exist | `/step` skill |
| A step is ≤ ~200 lines | You can read 200 lines carefully in about 10 minutes. You cannot read 2,000 | `diff-budget.sh` hook (blocks at 300) |
| The agent explains its own diff | You get a reading order and the risky lines | `/explain-diff` skill |
| You commit, not the agent | The commit means "I read this" | CLAUDE.md + your habit |
| One branch = one PR = one idea, deleted on merge | No 200-branch graveyard | `merge-when-green.sh --delete-branch`, GitHub auto-delete, `/tidy-branches` |
| No new dependency without asking | Every package is code you did not read | `/add-dependency` skill |
| A second agent reviews before you do | It finds the obvious problems, so you can think about design | `reviewer` subagent |
| Never read `.env`, force-push, push to main, skip tests | You cannot undo these | `settings.json` deny rules + hooks |

### Settings that help you watch

- Use **default permission mode** (it asks before edits), not auto-accept, while the code is new to you.
  Switch to auto-accept only for mechanical work you will read in the diff anyway.
- **Plan mode** (Shift+Tab twice) for anything new. The agent can read but not write until you approve.
- Keep sessions short: one task per session, then `/clear`. Long chats get slower, cost more, and the
  agent forgets the early rules.
- Read diffs in a real diff tool (VS Code, `git difftool`, GitHub PR "Files changed"), not in the chat.
- Use `git add -p` to stage hunk by hunk. It makes you look at every hunk.

## What goes where (Claude Code)

| Need | Use | Example in this kit |
|---|---|---|
| Rules for every session (short!) | `CLAUDE.md` (under ~150 lines) | `template/CLAUDE.md` |
| A procedure used sometimes | Skill (`.claude/skills/<name>/SKILL.md`) | `step`, `explain-diff`, `adr` |
| A rule that must never break | Hook (exit 2 blocks) or `permissions.deny` | `diff-budget.sh`, `guard-secrets.sh` |
| Work that would flood the chat (search, review) | Subagent (separate context) | `agents/reviewer.md` |
| The same check for humans and agents | Git hook (lefthook) + CI | `lefthook.yml`, `ci.yml` |
| Personal preferences | `~/.claude/CLAUDE.md`, `.claude/settings.local.json` (git-ignored) | |

Keep CLAUDE.md short. Each line costs context in every session. Move long "how to" text into skills,
which load only when they are needed.

## Prompts that work

- Give the goal, the files, and what "done" looks like: *"Add search by title to notes. Backend
  endpoint + web input. Done = a test for each, `make check` green."*
- Ask for the plan, not the code: *"/step add search by title"*.
- When the output is wrong, say what is wrong and why. Do not just say "fix it". The why helps it
  generalise.
- Ask it to teach you: *"Explain why you used `Limit` here and not `Pageable`."* Your review gets
  better each week. This matters most in the language you are learning (Swift).

## Who writes what

| Task | Agent | You |
|---|---|---|
| Boilerplate, tests, migrations, CRUD | Writes it | Read it, check edge cases |
| Architecture, data model, API shape | Proposes 2-3 options | Decide; write an ADR (`/adr`) |
| Security, auth, payments | Writes it and explains every line | Read twice; the `reviewer` agent too |
| Prompts for your app's LLM features | Drafts | Test them on real inputs (evals, see doc 11) |
| Naming, product copy | Suggests | Decide |

## Real examples

- Anthropic, *Claude Code best practices* and *Steering Claude Code: CLAUDE.md, skills, hooks, subagents*.
- Google, *Engineering practices: code review* (small CLs, what to look for): <https://google.github.io/eng-practices/review/>
- This repo: `.claude/hooks/guard-git-push.sh` (a hook that has worked for months), `scripts/merge-when-green.sh`,
  and the "Saving time and tokens" section in the root `CLAUDE.md`.
