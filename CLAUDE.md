# Saynata

An iOS app for a Vietnamese English learner: look up words, translate sentences, hear them aloud, and
practise saying the meaning with a score. Open source, built mostly with AI help by one developer who is
learning Swift and English at the same time.

| Part | Stack | Job | Feature docs |
|---|---|---|---|
| `EnglishTranslation/` | SwiftUI, iOS 18 | The app, plus the Share and Translation extensions (they compile the app folder); accounts, word and sentence results, History and Liked, App Intents (Explain copied text, Quick explain) | doc-4, doc-5, doc-10, doc-17, doc-21, doc-22 |
| `EnglishTranslation/SaynataMac/` | SwiftUI + AppKit, macOS 15 | Menu-bar Mac app with a floating panel (⌥⇧Space) and Services; shares the iOS app folder | doc-20 |
| `backend/` | Spring Boot 4, Java 17, Postgres, Flyway; `deepseek-v4.1-flash` through the STEYG gateway (Claude Haiku 5.5 as fallback) | Word and sentence API with a shared cache-first DB, accounts and limits (`limits/ClaudeGate`), language lines, liked items, prefill queue, admin API, AI pictures | doc-4, doc-5, doc-11, doc-13, doc-15, doc-17, doc-18 |
| `pipeline/` | Python 3.12, uv, Claude Sonnet 5.5 (through `llm.py`), Codex CLI | Builds the bundled dictionary and media, AI pictures, prefill and local collection, book words (books convert, collect, review), language lines | doc-6, doc-15, doc-18 |
| `admin/` | React, Vite, TypeScript, Refine, shadcn/ui | Admin CMS at `admin.saynata.com`: words, sentences, media, users, sources | doc-13, doc-14 |
| `extension/` | Chromium MV3, TypeScript, Vite, Vitest | Browser extension: select English, see the simple explanation | doc-19 |
| `web/` | Next.js 16, TypeScript, Tailwind 4, GSAP, Vitest | The learner website (homepage, sign-in and sign-up), deployed next to the backend | doc-17, doc-23 |

**Details of every part** (endpoints, tables, Flyway versions, env keys, commands): [doc-24 System map](backlog/docs/features/doc-24%20-%20System-map.md).
Read it only for the part you touch.

Read before working:
- Goal, requirements, decisions: `backlog/docs/doc-1 - Vision-and-spec.md`
- Why each choice was made, the strategy, and the progress story: `backlog/docs/story/` (doc-7, doc-8, doc-9).
  When the developer makes a decision, add a row to doc-7 the same day with the reason in their words and the
  options that lost. No reason given? Write "Reason: not recorded" and add it to the questions list.
  Add a line to doc-9 at the end of each working day.
- How each flow works (files, lines, diagrams): `backlog/docs/features/`
- Daily workflow: `backlog/docs/doc-2 - Daily-workflow.md`
- UI work (colors, text styles, components, HIG rules): `docs/design/design-system.md`
- What's done and what's next: `backlog task list --plain`, and any In Progress task's notes

Workers: the main chat plans and reviews; `.claude/agents/implementer.md` (Sonnet, own worktree) builds one task and
opens a PR into its feature branch (TASK-31 to 34 are features F1-F4). `.claude/hooks/guard-git-push.sh` blocks
force-push and pushes to main in every permission mode.

Full test suites: `cd backend && ./mvnw test` · `cd pipeline && uv run pytest` (the Postgres tests need `TEST_DATABASE_URL`, else they are skipped) · `cd admin && npm test` · `cd extension && npm test` · `cd web && npm test` · iOS in Xcode (⌘U). While working, run only the tests of the part you changed (see "Saving time and tokens").
Merge a PR when CI is green: `scripts/merge-when-green.sh <PR>` (no Claude chat needed).
Install on the developer's real iPhone (build, then install or replace; open it by hand): `scripts/install-on-phone.sh` (free Apple ID: signs without App Groups and the default-translation-app capability; `PAID_ACCOUNT=1` for the real entitlements).
Deploy the backend to a VPS: `cd backend && ./scripts/deploy.sh` on the server, or automatically: `.github/workflows/deploy.yml` runs it over SSH after CI passes on main, then builds the admin web app and copies `admin/dist` to the server (guide and secrets: `backlog/docs/guides/doc-11 - Deploy-to-a-VPS.md`).

**Simulator: always iPhone 16 Pro (iOS 18.5)** for iOS tests, builds and screenshots, by agents and in Test it cards:
`-destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'`. It is the developer's device, so results match what they see.

## Product rule: explain first, translate last

Saynata teaches English. It is not a translator. For every word and sentence, the main result is a **simple
English explanation** of the meaning (short, plain words, B1-B2 level), so the learner thinks in English.
The target language (Vietnamese, etc.) is a small helper line at the **bottom** of the result, never the headline.

- UI order: simple English explanation, then words (IPA, type, level, meaning), then the target-language line last.
- The target-language line is a row titled with the picked language (for example "Vietnamese" or "Korean") that the user taps to open, per result. By default it **remembers the last choice** (it starts closed on a new install, then stays the way the user left it).
  Vietnamese shows the dictionary text; other languages show the simple explanation translated on the device (Apple Translation).
  Settings has a "Show translation" option to change this: Remember last choice (default), Always open, or Collapsed. For a signed-in user the choice follows the account (all devices).
- Words in a sentence use the same word card as a word search, in compact form.
- Prompts and response models: ask the LLM for the English explanation first; the target-language text is a
  secondary field. Do not name or design a feature as "translate X".
- When a doc, task, or mockup says "translation first", this rule wins. Update the doc.

## UI rule: icon-only buttons

Buttons have **no text labels** (no "Listen", "Speak", "Copy"). Use an icon only, with an accessibility label
for VoiceOver. This applies to mockups, designs, and SwiftUI code. Add a visible word to a button only when the
developer asks for it. Section rows and headings (for example "Vietnamese", "How to use it") are not buttons
and keep their text.

<!-- BACKLOG.MD GUIDELINES START -->
<!-- backlog.md-instructions-version: 1.53.0 -->
<CRITICAL_INSTRUCTION>

## Backlog.md Workflow

This project uses Backlog.md for task and project management.

**At the beginning of each conversation in this project, run `backlog instructions overview` before answering or taking action. Re-read it only if you have not read it yet in the current conversation.**

Use the overview to decide whether to search, read, create, or update Backlog tasks.

Before task lifecycle actions, read the matching detailed guide:
- `backlog instructions task-creation` before creating or splitting tasks
- `backlog instructions task-execution` before planning, changing status or assignee, adding a plan or implementation notes, or implementing task work
- `backlog instructions task-finalization` before checking acceptance criteria, writing final summaries, or moving tasks to terminal statuses

Use `backlog <command> --help` before running unfamiliar commands. Help shows options, fields, and examples.

Do not edit Backlog task, draft, document, decision, or milestone markdown files directly. Use the `backlog` CLI so metadata, relationships, and history stay consistent.

</CRITICAL_INSTRUCTION>
<!-- BACKLOG.MD GUIDELINES END -->

## Working with the developer

- **Feature status with every "please test".** When you ask the developer to test, start with a short status
  table of all features (F1-F4 and other user-facing tasks): done and merged, ready to test now, in progress,
  not started. Say exactly which ones this build contains, so they do not test something that is not built.
  Give branch-switch commands as `git fetch origin && git switch <branch> && git pull`.
- **Mockup before UI code.** Any change to how a screen looks (layout, new section, separators, labels, order)
  starts with a mockup (an inline visual or a page) and waits for the developer's choice. Only then change
  SwiftUI code. Bug fixes that keep the agreed design (flicker, wrong colour token) do not need a mockup.

## Conventions

Follow the code that is already there; these are the rules it uses (TASK-12).

- **iOS** (`EnglishTranslation/`): SwiftUI views in `Views/<Flow>/` (Translate, Word, Sentence, SelectedText,
  Settings, Shared); state in `@Observable` classes (`Stores/`, `Speech/`) injected with `.environment`, so every
  `#Preview` that needs one adds it (for example `.environment(SpeechPlayer.silent())`). Colors, spacing, radius and
  text styles only from `Theme` and `DesignSystem/Components` (`IconButton`, `cardSurface()`…), per
  `docs/design/design-system.md`. System APIs sit behind a small protocol so tests use a fake. Tests use Swift
  Testing (`import Testing`, `@Test`, `#expect`) in `EnglishTranslationTests/`.
  Test: ⌘U, or `xcodebuild test -project EnglishTranslation/EnglishTranslation.xcodeproj -scheme EnglishTranslation -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' -only-testing:EnglishTranslationTests -parallel-testing-enabled NO`.
- **Backend** (`backend/`): one package per feature (`translation/`, `word/`, `claude/`, `cache/`, `auth/`, `limits/`, `prefill/`, `suggest/`, `liked/`, `common/`),
  each with its controller, service, repository and records. Errors are `ProblemDetail` responses from
  `common/ApiExceptionHandler` (an `ApiException` has a `code` the app can read, like `sign_in_required`). Any new code that calls Claude goes through `limits/ClaudeGate` first. Schema changes only as a new Flyway file `V<n>__<what>.sql`; never edit an old one.
  A prompt change bumps its version in `application.properties` (`app.claude.*-prompt-version`). Secrets come from env
  or `backend/.env` (git-ignored); new keys go in `.env.example` and doc-11. Tests are JUnit 5 + `@SpringBootTest`
  with a fake Claude key; they never call the real API. Test: `cd backend && ./mvnw -B test`.
- **Pipeline** (`pipeline/`): one module per step in `src/pipeline/` (`senses`, `examples`, `usage`, `forms`, `media`, `media_check`, `media_generate`,
  `validate`, `export`), run through `cli.py`; progress is saved in `pipeline.db`, so every step can resume.
  Agents never start paid passes (LLM, large media runs); they write the code and say the command and its cost.
  Test: `cd pipeline && uv run pytest`.
- **Everywhere**: branches `feature/f<n>-<name>` for features and `f<n>/task-<id>` for their tasks, `fix/<what>` for
  fixes; merge, never rebase or force-push; every PR has a "Test it" card; only the main chat marks a task Done,
  after the developer has tested it. Commit messages start with the task ID.
- **Test branch `feature/local`** (developer's rule, 2026-10-16): finished work is merged into `feature/local` first,
  not into `main`. The developer tests from `feature/local`; only after they say the test succeeded does that work go
  to `main`. New PRs target `feature/local` (or their feature branch, which is then merged into `feature/local`).

## Feature docs

`backlog/docs/features/` has one page per flow (files, `file:line` links, Mermaid diagrams, errors, tests, known gaps).
Read the matching page before changing a flow. When a change moves, renames, or changes the logic of
anything on a page, update that page in the same commit, including line numbers and the "Last traced" date.
Edit pages with `backlog doc update <id> --content` (the files have frontmatter). A new feature gets a new page
from the template in doc-3 (Features overview), created with `backlog doc create "<Feature>" -p features`.

Keep doc-24 (System map) true too: when a change adds a part, changes the stack or a model, or changes a
command, update it in the same commit. Touch the short table at the top of this file only when a part is added or
its stack changes. Before every commit, run `python3 scripts/check_docs.py`
and fix what it reports (links to missing files or past the end of a file).

## Saving time and tokens

Developer's rule (2026-10-24). Every call re-reads the whole conversation, so a long chat makes every step slower
and more expensive.

- **One task per session.** After a task is finished (PR open or merged), recommend `/clear` before the next one.
  Keep a session under about 150k tokens of context; a hook warns when it passes 120k.
- **Focused tests while working.** Run only the tests for the code you changed, never the full suite:
  - iOS: `-only-testing:EnglishTranslationTests/<SuiteName>` (one or more suites) instead of the whole target.
  - Backend: `./mvnw -B test -Dtest='<ClassName>*'`.
  - Pipeline: `uv run pytest tests/test_<module>.py`; admin, extension, web: `npx vitest run <file>`.
  - Full suites run in CI only on PRs into `main` (and pushes to `main`). PRs into `feature/local` and feature
    branches run only the jobs for the parts they change.
- **No agent UI testing by default.** Do not drive the simulator, the browser pane or the phone to check a change.
  Write the checks as steps in the PR's "Test it" card; the developer, or another agent they start, runs them.
  Only when the developer asks: one screenshot at the end, `scale: 0.5`.
- **Short tool output.** Pipe builds and test runs through `| tail -40` (or grep the result line); never print a
  full build log, a whole large file or a long JSON response into the chat.
- **Short briefs.** A subagent or new session gets a fresh, short brief (files, goal, what done looks like), not a
  fork of a long chat. Use Sonnet for mechanical work (merges, doc updates, backlog notes, small test fixes).
- **Routine jobs are scripts.** Merging when CI is green, deploys and phone installs run from scripts
  (`scripts/merge-when-green.sh`, `scripts/install-on-phone.sh`), not from a long chat.
