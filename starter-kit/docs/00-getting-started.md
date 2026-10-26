# 00. Getting started: a step-by-step plan

## Phase 0: One-time setup on your Mac (30 min)

```bash
brew install git jq gh lefthook gitleaks xcodegen uv node@22
brew install --cask temurin@21 orbstack     # orbstack = Docker for Mac
gh auth login
cd ~/code/saynata && git fetch origin && git switch claude/youthful-newton-9smyhp && git pull
```

Optional: move the kit into its own repo, so it is separate from Saynata:

```bash
git subtree split --prefix starter-kit -b starter-kit
gh repo create starter-kit --private
git push git@github.com:<you>/starter-kit.git starter-kit:main
```

## Phase 1: Check the kit on your Mac (1 hour, once)

The iOS stack was never compiled, so test it in a throwaway project first:

```bash
starter-kit/new-project.sh /tmp/kit-test --name "KitTest" --stacks backend,web,python,ios
cd /tmp/kit-test && (cd web && npm ci) && make up && make check
```

- If `make check-ios` fails, ask Claude to fix it in `starter-kit/stacks/ios`, not in the test copy.
- With Docker running, the 2 Testcontainers tests run for real now. Check that they pass.

## Phase 2: Create the real project (20 min)

```bash
starter-kit/new-project.sh ~/code/my-app --name "My App" --stacks backend,web,ios \
  --java-package com.loc.myapp --pitch "One line about the app."
cd ~/code/my-app
scripts/doctor.sh                       # lists what is missing
cp .env.example .env; cp backend/.env.example backend/.env; cp web/.env.example web/.env.local
lefthook install
make up && make check
gh repo create my-app --private --source . --push
gh label create human-reviewed --color 0E8A16
```

On GitHub:
- Settings → General → turn on "Automatically delete head branches".
- Settings → Rules → protect `main`: require a PR and green CI, and block force-push.

## Phase 3: The first decisions (1 hour)

1. Open `claude` in the repo. Run `/adr` for each big choice: the database, hosting, auth, and which stacks you use.
2. Edit `CLAUDE.md`: write the real pitch and add your product rules (like Saynata's "explain first").
3. Keep the `notes` example until your first real feature works. It shows the agent the patterns.
   Then delete it in its own PR.

## Phase 4: The daily loop (every task)

| # | You | Claude |
|---|---|---|
| 1 | `git switch -c feat/<what>` | |
| 2 | `/step <task in one sentence + what "done" means>` | Writes a plan (files, size, tests), then **stops** |
| 3 | Read the plan and say "go", or change it | |
| 4 | | Writes the code and tests, runs `make check-<part>` |
| 5 | | Runs `/explain-diff` |
| 6 | Read the diff in VS Code, then `git add -p` (hunk by hunk) | Answers your "why?" questions |
| 7 | `git commit -m "feat(x): ..."` | |
| 8 | Repeat 2-7 until the task is done (each step ≤ ~200 lines) | |
| 9 | `git push -u origin feat/<what>` and `gh pr create` | |
| 10 | "Use the reviewer agent on this branch" | Lists findings (blocker / should-fix / nit) |
| 11 | Fix the blockers, read the PR once more on GitHub, add the `human-reviewed` label | |
| 12 | `scripts/merge-when-green.sh <PR>` (squash merge + delete the branch) | |
| 13 | `/clear` before the next task | |

- When the diff-budget hook fires: stop, review, commit, then continue. Raise the limit only for
  mechanical work: `DIFF_BUDGET=600 claude`.
- A new library: Claude shows the `/add-dependency` card, and you decide.
- Code you do not understand: ask "explain this line and link the docs". This matters most for Swift.

## Phase 5: Weekly (15 min, Friday)

- `scripts/cleanup-branches.sh` (dry run), then `--delete`.
- Merge the green Dependabot PRs.
- Once you have users: check Sentry issues, uptime, and the LLM cost (doc 12).

## Phase 6: When the first real users arrive

1. Create Sentry projects and put the DSNs in env. Set `APP_RELEASE` to the git SHA when you deploy.
2. Point an uptime check (UptimeRobot or Better Stack) at `/actuator/health/readiness`.
3. Add PostHog with the 5 core events (doc 08).
4. Set `LOG_FORMAT=ecs` in production.

## Phase 7: When you add an LLM feature

1. Copy the pattern from `python/src/app/llm.py`: one door, prompt versions, a budget.
2. Before you change any prompt, collect 20-50 real inputs as an eval set (doc 11).
3. Cache the results, with `prompt_version` in the cache key.

## Phase 8: Keep the kit alive

- When a project teaches you something, fix the kit, not only that project.
- Every 3 months: update the versions in `stacks/*`, then run Phase 1 again.

## For Saynata, today (10 min)

```bash
cd ~/code/saynata
bash starter-kit/template/scripts/cleanup-branches.sh            # dry run: merged + stale branches
bash starter-kit/template/scripts/cleanup-branches.sh --delete   # only after you read the list
```

Saynata merges work into `feature/local` before `main`, so the dry run may list some branches as "stale"
that are really merged into `feature/local`. Delete only the ones you recognise. Then turn on "Automatically
delete head branches" in Saynata's GitHub settings.
