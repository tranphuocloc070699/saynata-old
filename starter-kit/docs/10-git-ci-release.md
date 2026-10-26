# 10. Git, CI, and releases

## Branches: short-lived, deleted on merge

Saynata has more than 200 branches, because of long-lived branches (`feature/local`, `feature/f1-…`),
task branches stacked on them, and no automatic delete. For a new project, keep it simple:

- **`main` is always deployable.** Work happens on short-lived branches (`feat/notes-search`,
  `fix/login-timeout`) that live for hours or days, not weeks.
- One branch = one PR = one idea (under ~400 lines). Big features are split into steps behind a
  **feature flag**, so half-done work can merge without being visible.
- **Squash merge** to `main` (one commit per PR, easy to revert). `merge-when-green.sh` does this.
- **Delete the branch on merge**: turn on GitHub's "Automatically delete head branches", and
  `merge-when-green.sh` passes `--delete-branch`. Run `scripts/cleanup-branches.sh` monthly.
  (For Saynata today: `scripts/cleanup-branches.sh` from the kit works there too. Do a dry run first.)
- No `feature/local`-style test branch. Test the PR branch itself (preview deploy, or check it out locally).

## Commits

Use Conventional Commits, checked by lefthook: `feat(notes): add search by title`, `fix(api): handle timeout`.
Types: feat, fix, docs, refactor, test, chore, perf, build, ci, revert. `!` marks a breaking change.
You get a readable history and automatic changelogs.

## Protect `main` (GitHub → Settings → Rules)

- Require a PR. Require CI to pass. Block force-push and deletion.
- Solo: GitHub does not let you approve your own PR. Instead, use the `human-reviewed` label, which you
  add after reading the diff. `merge-when-green.sh` will not merge without it.

## CI (`template/.github/workflows/ci.yml`)

- `paths-filter`: a PR runs only the jobs for the parts it changes. Pushes to `main` run everything (a Saynata rule).
- Each job runs the same `make check` you run locally. There is one definition of "green".
- Secret scan (gitleaks) on every PR.
- `concurrency` cancels old runs when you push again.
- Dependabot: weekly, grouped minor/patch updates (few PRs). Pin GitHub Actions to a commit SHA when you
  can (supply-chain safety). Dependabot keeps the SHA up to date.

## Releases and deploys

- Tag releases (`v1.4.0`) with **release-please** (it reads the Conventional Commits and opens a release PR with the changelog).
- Deploy from CI after `main` is green (Saynata: `deploy.yml` → SSH → `deploy.sh`). Use the git SHA as
  `APP_RELEASE` and as the Sentry release.
- Migrations run before the new code starts, and must work with the old code too (see doc 02).
- Have one rollback command, and try it once before you need it.

## Real examples

- trunkbaseddevelopment.com: short-lived feature branches.
- Conventional Commits: <https://www.conventionalcommits.org>
- `googleapis/release-please`
- This repo: `.github/workflows/ci.yml` (paths-filter), `deploy.yml`, `scripts/merge-when-green.sh`.
