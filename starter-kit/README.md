# Starter kit: AI writes, you read every line

A boilerplate for new projects where AI agents write the code and a human reviews every line.
It is built from Saynata's lessons (200+ branches, rules that were skipped, review that could not keep up)
and from current best practices for each stack.

```bash
starter-kit/new-project.sh ~/code/my-app --name "My App" \
  --stacks backend,web,python,ios --java-package com.me.myapp --pitch "One line about the app."
```

You get a git repo with one commit: `CLAUDE.md` filled in for the stacks you picked, Claude Code hooks
and skills, CI and Dependabot trimmed to your stacks, scripts, a Postgres compose file, and working sample
code (a "notes" feature) in each stack.

## What is inside

```
starter-kit/
├── new-project.sh            the generator
├── docs/                     best practices + real examples (read 01 first)
├── template/                 copied into every project
│   ├── CLAUDE.md             short rules; stack rules are appended
│   ├── .claude/
│   │   ├── settings.json     deny: read .env, force-push, push to main, --no-verify
│   │   ├── hooks/            diff-budget.sh · guard-secrets.sh · guard-git-push.sh
│   │   ├── skills/           step · explain-diff · adr · add-dependency · tidy-branches
│   │   └── agents/           reviewer (read-only, independent review)
│   ├── .github/              ci.yml (paths-filter, per stack) · dependabot · PR template
│   ├── scripts/              doctor.sh · cleanup-branches.sh · merge-when-green.sh
│   ├── docs/adr/             decision record template
│   ├── Makefile              make up · make check · make check-<part>
│   ├── compose.yaml          Postgres 18 for local dev
│   ├── lefthook.yml          git hooks: gitleaks, formatters, commit message
│   └── .editorconfig .gitignore .env.example
└── stacks/
    ├── backend/  Spring Boot 4.1, Java 21, Postgres, Flyway, Testcontainers, Sentry, OpenAPI, Docker
    ├── web/      React 19, Vite 8, TS strict, TanStack Query, React Router, zod, Vitest + MSW, Sentry
    ├── python/   uv, ruff, pyright strict, pytest, pydantic-settings, structlog, Anthropic SDK wrapper
    └── ios/      SwiftUI, iOS 18, Swift 6 strict, XcodeGen, Swift Testing, Sentry
```

## How the "read every line" workflow is enforced

| Problem in Saynata | What the kit does |
|---|---|
| Big diffs you could not review | `diff-budget.sh` blocks edits after 300 changed lines; `/step` plans ≤ 200-line steps and waits for "go" |
| You did not know why code was written | `/explain-diff` gives a reading order, the risky lines, and new language features with doc links |
| 200+ branches | One branch per PR, squash + delete on merge, `cleanup-branches.sh`, `/tidy-branches` |
| Rules written down but skipped | Hooks + deny rules + lefthook + CI run the same `make check` |
| Agents using old APIs | Strict types everywhere (TS strict, pyright strict, Swift 6, warnings as errors) |
| Unreviewed dependencies | `/add-dependency` card: why, size, health, licence; then an ADR |
| Merging without reading | `merge-when-green.sh` needs an approval or the `human-reviewed` label |
| Secrets near agents | Deny `Read(.env*)`; a hook blocks `cat .env`, `env`, and `printenv`; gitleaks in hooks and CI |

## What was tested while building it

| Part | Result |
|---|---|
| backend | `./mvnw verify`: Spotless + 3 web tests pass; 2 Testcontainers tests skip without Docker (they run in CI). Also ran the jar against a real Postgres 16: create/list/404/OpenAPI/JSON logs work. That run found and fixed a real bug (`createdAt` was null after create) |
| web | `make check`: oxlint, prettier, `tsc -b`, 2 tests, production build |
| python | `make check`: ruff, format, pyright strict (0 errors), 6 tests. No real LLM call was made (it costs money). Run `uv run app summarize some.txt` yourself |
| ios | **Not compiled** (built on Linux). Run `make -C ios check` on a Mac first and fix what Xcode reports |
| generator | Generated 1-stack and 4-stack projects; `make check-backend/web/python` passed inside the generated project |
| hooks | Fed fake inputs: blocks `cat .env`, `env`, `printenv`, `source .env`, push to main, force-push, and edits over the diff budget; allows `.env.example`, normal pushes, and `make check` |

## Read the docs in this order

1. [Working with AI agents](docs/01-working-with-ai.md): the loop, what goes in CLAUDE.md vs skills vs hooks
2. [Database](docs/02-database.md) · [Spring Boot](docs/03-backend-spring.md) · [React](docs/04-web-react.md) ·
   [Swift](docs/05-ios-swift.md) · [Python](docs/06-python.md)
3. [Observability: Sentry, logs, uptime](docs/07-observability.md) · [Analytics: GA4, PostHog](docs/08-analytics.md) ·
   [Env and secrets](docs/09-env-and-secrets.md)
4. [Git, CI, releases](docs/10-git-ci-release.md) · [AI services: LLM APIs, CLIs](docs/11-ai-services.md) ·
   [Project management](docs/12-project-management.md)

## Keep the kit alive

- When a project teaches you something, change the kit (a hook, a skill, a doc line), not just that project.
- Every 3 months, update the versions in `stacks/*` and run each `make check`. Dependabot in a project only updates that project.
- To move the kit into its own repo: `git subtree split --prefix starter-kit -b starter-kit` then push that branch to a new repo.

## Sources

- Anthropic, *Steering Claude Code: when to use CLAUDE.md, skills, hooks, and subagents*: <https://www.claude.com/blog/steering-claude-code-skills-hooks-rules-subagents-and-more>
- Spring Boot reference, *Tracing* and *Structured logging*: <https://docs.spring.io/spring-boot/reference/actuator/tracing.html>
- Postgres wiki, *Don't Do This*: <https://wiki.postgresql.org/wiki/Don%27t_Do_This>
- `alan2207/bulletproof-react`: <https://github.com/alan2207/bulletproof-react>
- PostHog, *Product analytics best practices*: <https://posthog.com/docs/product-analytics/best-practices>
- GitHub Docs, *Managing the automatic deletion of branches*: <https://docs.github.com/en/enterprise-cloud@latest/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-the-automatic-deletion-of-branches>
- Hivenet, *LLM production checklist* (timeouts, retries, idempotency): <https://www.hivenet.com/post/llm-production-checklist>
- *Secrets management best practices* (SOPS/age, 1Password, gitleaks): <https://knowledgelib.io/software/security/secrets-management/2026>
- WWDC25 *Explore concurrency in SwiftUI*, summary: <https://dev.to/arshtechpro/wwdc-2025-explore-concurrency-in-swiftui-1dm8>
- Python templates using uv + ruff + pyright: <https://github.com/Ranteck/PyStrict-strict-python>, <https://github.com/dhkts1/python-starting-project>
- Google, *Engineering practices: code review*: <https://google.github.io/eng-practices/review/>
- *The Twelve-Factor App*: <https://12factor.net>
