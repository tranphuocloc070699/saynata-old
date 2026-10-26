#!/usr/bin/env bash
# Lists (and with --delete, removes) branches that are merged into main, and optionally stale ones.
#
#   scripts/cleanup-branches.sh                   # dry run: show merged and stale branches
#   scripts/cleanup-branches.sh --delete          # delete merged branches, local and on origin
#   scripts/cleanup-branches.sh --delete --stale  # also delete stale branches (no commit for STALE_DAYS, no open PR)
#
# Never touches main, the current branch, or a branch with an open PR (needs gh for the PR check).
set -euo pipefail

base="${BASE_BRANCH:-main}"
stale_days="${STALE_DAYS:-30}"
delete=false
include_stale=false
for arg in "$@"; do
  case "$arg" in
    --delete) delete=true ;;
    --stale) include_stale=true ;;
    *) echo "usage: $0 [--delete] [--stale]" >&2; exit 2 ;;
  esac
done

git fetch origin --prune --quiet
current=$(git branch --show-current)

open_pr_branches=""
if command -v gh >/dev/null 2>&1; then
  open_pr_branches=$(gh pr list --state open --limit 500 --json headRefName --jq '.[].headRefName' 2>/dev/null || true)
fi

keep() {
  local b="$1"
  [ "$b" = "$base" ] || [ "$b" = "$current" ] || [ "$b" = "HEAD" ] && return 0
  grep -qxF "$b" <<<"$open_pr_branches" && return 0
  return 1
}

# Merged: local and remote branches whose tip is in origin/main.
merged=$( {
  git branch --merged "origin/$base" --format='%(refname:short)'
  git branch -r --merged "origin/$base" --format='%(refname:short)' | sed -n 's#^origin/##p'
} | sort -u)

# Stale: remote branches with no commit for stale_days days that are not merged.
cutoff=$(( $(date +%s) - stale_days * 86400 ))
stale=$(git for-each-ref refs/remotes/origin --format='%(committerdate:unix) %(refname:short)' \
  | awk -v c="$cutoff" '$1 < c { sub("^origin/", "", $2); print $2 }' | sort -u | grep -vxF -f <(echo "$merged") || true)

echo "Merged into $base:"
for b in $merged; do keep "$b" || echo "  $b"; done
echo "Stale (no commit for $stale_days days, not merged, no open PR):"
for b in $stale; do keep "$b" || echo "  $b"; done

$delete || { echo; echo "Dry run. Add --delete to remove merged branches (and --stale for stale ones)."; exit 0; }

to_delete="$merged"
$include_stale && to_delete="$merged $stale"
for b in $to_delete; do
  keep "$b" && continue
  git show-ref --verify --quiet "refs/heads/$b" && git branch -D "$b" >/dev/null && echo "deleted local  $b"
  git show-ref --verify --quiet "refs/remotes/origin/$b" && git push origin --delete "$b" --quiet && echo "deleted remote $b"
done
