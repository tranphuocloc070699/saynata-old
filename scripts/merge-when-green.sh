#!/usr/bin/env bash
# Waits for a PR's CI checks, then merges it with a merge commit (never squash or rebase).
# Saves a long Claude chat that only waits for CI. After the merge, scripts/clean-branches.sh removes the PR's
# local branch and its worktree (GitHub deletes the remote branch itself).
#
#   scripts/merge-when-green.sh 163            # one PR
#   scripts/merge-when-green.sh 163 165        # several, one after the other
#
# A PR into main is refused: main gets the feature/local release PR, merged by the developer on GitHub.
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "usage: $0 <pr-number> [<pr-number> ...]" >&2
  exit 2
fi

for pr in "$@"; do
  base=$(gh pr view "$pr" --json baseRefName --jq .baseRefName)
  title=$(gh pr view "$pr" --json title --jq .title)
  head=$(gh pr view "$pr" --json headRefName --jq .headRefName)
  if [ "$base" = "main" ]; then
    echo "PR #$pr goes into main: merge it yourself on GitHub. Skipped." >&2
    continue
  fi

  echo "PR #$pr ($title) into $base: waiting for CI..."
  # Wait until checks are registered, then until they finish. Exit code 8 = still pending, 1 = a check failed.
  sleep 10
  if ! gh pr checks "$pr" --watch --interval 20 > /dev/null; then
    echo "PR #$pr: a check failed. Not merged:" >&2
    gh pr checks "$pr" | grep -v -E '\bpass\b|\bskipping\b' >&2 || true
    exit 1
  fi

  gh pr merge "$pr" --merge
  echo "PR #$pr merged into $base."
  "$(dirname "$0")/clean-branches.sh" --apply "$head" || echo "PR #$pr: cleanup of $head failed; run scripts/clean-branches.sh to see why." >&2
done
