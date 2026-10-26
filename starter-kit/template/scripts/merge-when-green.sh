#!/usr/bin/env bash
# Waits for a PR's CI checks, then merges it. Refuses a PR that a human has not reviewed:
# it needs an approval, or (solo developer: GitHub does not let you approve your own PR)
# the label "human-reviewed", which you add after reading every line.
#
#   scripts/merge-when-green.sh 163            # one PR
#   scripts/merge-when-green.sh 163 165        # several, one after the other
#   MERGE_METHOD=merge scripts/merge-when-green.sh 163   # default is squash (one commit per PR on main)
set -euo pipefail

method="${MERGE_METHOD:-squash}"
if [ $# -eq 0 ]; then
  echo "usage: $0 <pr-number> [<pr-number> ...]" >&2
  exit 2
fi

for pr in "$@"; do
  title=$(gh pr view "$pr" --json title --jq .title)
  decision=$(gh pr view "$pr" --json reviewDecision --jq .reviewDecision)
  labelled=$(gh pr view "$pr" --json labels --jq '[.labels[].name] | index("human-reviewed") != null')
  if [ "$decision" != "APPROVED" ] && [ "$labelled" != "true" ]; then
    echo "PR #$pr ($title): not reviewed yet. Read it, then: gh pr edit $pr --add-label human-reviewed. Skipped." >&2
    continue
  fi

  echo "PR #$pr ($title): waiting for CI..."
  sleep 10   # let the checks register
  if ! gh pr checks "$pr" --watch --interval 20 > /dev/null; then
    echo "PR #$pr: a check failed. Not merged:" >&2
    gh pr checks "$pr" | grep -v -E '\bpass\b|\bskipping\b' >&2 || true
    exit 1
  fi

  gh pr merge "$pr" "--$method" --delete-branch
  echo "PR #$pr merged ($method) and its branch deleted."
done
