#!/usr/bin/env bash
# Removes worktrees and branches whose work is already merged. Dry run by default: it only prints the plan.
#
#   scripts/clean-branches.sh                      # dry run, whole repo
#   scripts/clean-branches.sh --apply              # delete merged worktrees and local branches
#   scripts/clean-branches.sh --apply --remote     # ...and merged branches on GitHub too
#   scripts/clean-branches.sh --apply fix/foo      # only these branches (merge-when-green.sh uses this)
#
# Run it from anywhere inside the repo. Safe to run again: it only touches work that is already merged.
#
# "Merged" means one of:
#   - the branch tip is already in origin/main or origin/feature/local, or
#   - a merged PR had this branch as its head, and the branch has no commits after that PR (an old squash merge).
# Never touched: main, feature/local, branches with an open PR or used as an open PR's base, the worktree this
# script runs in, and worktrees with uncommitted changes. Everything it keeps is listed with the reason.
set -euo pipefail

apply=0
remote=0
only=()
for arg in "$@"; do
  case "$arg" in
    --apply) apply=1 ;;
    --remote) remote=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    -*) echo "unknown option: $arg" >&2; exit 2 ;;
    *) only+=("$arg") ;;
  esac
done

repo=$(git rev-parse --show-toplevel)
here=$(cd "$repo" && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "1/5 Fetching origin..."
git -C "$repo" fetch --prune --quiet origin
for ref in origin/main origin/feature/local; do
  git -C "$repo" rev-parse --verify --quiet "$ref" > /dev/null || { echo "$ref is missing. Stopped, nothing changed." >&2; exit 1; }
done

echo "2/5 Reading PRs from GitHub..."
gh pr list --state open --limit 500 --json headRefName,baseRefName \
  --jq '.[] | .headRefName, .baseRefName' > "$tmp/open" \
  || { echo "Could not read open PRs (gh auth?). Stopped, nothing changed." >&2; exit 1; }
gh pr list --state merged --limit 2000 --json headRefName,headRefOid \
  --jq '.[] | "\(.headRefName) \(.headRefOid)"' > "$tmp/merged" \
  || { echo "Could not read merged PRs. Stopped, nothing changed." >&2; exit 1; }
gh pr list --state closed --limit 2000 --json headRefName,state \
  --jq '.[] | select(.state == "CLOSED") | .headRefName' > "$tmp/closed" || true
printf '%s\n' main feature/local >> "$tmp/open"

is_protected() { grep -qxF "$1" "$tmp/open"; }

in_scope() {
  [ ${#only[@]} -eq 0 ] && return 0
  local b
  for b in "${only[@]}"; do [ "$b" = "$1" ] && return 0; done
  return 1
}

# is_merged <branch-name> <commit>
is_merged() {
  local name=$1 tip=$2 oid
  git -C "$repo" merge-base --is-ancestor "$tip" origin/main 2> /dev/null && return 0
  git -C "$repo" merge-base --is-ancestor "$tip" origin/feature/local 2> /dev/null && return 0
  while read -r oid; do
    [ "$tip" = "$oid" ] && return 0
    git -C "$repo" merge-base --is-ancestor "$tip" "$oid" 2> /dev/null && return 0
  done < <(awk -v n="$name" '$1 == n { print $2 }' "$tmp/merged")
  return 1
}

why_kept() {
  if grep -qxF "$1" "$tmp/closed"; then echo "PR closed without merge"; else echo "no merged PR, has its own commits"; fi
}

echo "3/5 Worktrees..."
: > "$tmp/wt_remove"
: > "$tmp/in_kept_worktree"
main_wt=""
while IFS='|' read -r path branch; do
  if [ -z "$main_wt" ]; then main_wt=$path; echo "$branch" >> "$tmp/in_kept_worktree"; continue; fi
  if [ ! -d "$path" ]; then echo "  gone   $path (prunable)"; continue; fi
  name=${branch:-DETACHED}
  in_scope "$name" || { echo "$branch" >> "$tmp/in_kept_worktree"; continue; }
  real=$(cd "$path" && pwd -P)
  tip=$(git -C "$path" rev-parse HEAD)
  dirty=$(git -C "$path" status --porcelain | wc -l | tr -d ' ')
  if [ "$real" = "$here" ]; then
    echo "  keep   $path [$name] (this script runs here)"
  elif [ -n "$branch" ] && is_protected "$branch"; then
    echo "  keep   $path [$name] (open PR or long-lived branch)"
  elif ! is_merged "$name" "$tip"; then
    echo "  keep   $path [$name] ($(why_kept "$name"))"
  elif [ "$dirty" != 0 ]; then
    echo "  CHECK  $path [$name] (merged, but $dirty uncommitted file(s))"
  else
    echo "  remove $path [$name]"
    echo "$path" >> "$tmp/wt_remove"
    continue
  fi
  echo "$branch" >> "$tmp/in_kept_worktree"
done < <(git -C "$repo" worktree list --porcelain | awk '
  /^worktree /{ if (p != "") print p "|" b; p = substr($0, 10); b = "" }
  /^branch /{ b = substr($0, 8); sub("^refs/heads/", "", b) }
  END { if (p != "") print p "|" b }')

echo "4/5 Local branches..."
: > "$tmp/local_delete"
kept=0
while read -r b; do
  in_scope "$b" || continue
  is_protected "$b" && continue
  grep -qxF "$b" "$tmp/in_kept_worktree" && continue
  if is_merged "$b" "$(git -C "$repo" rev-parse "refs/heads/$b")"; then
    echo "$b" >> "$tmp/local_delete"
  else
    echo "  keep   $b ($(why_kept "$b"))"
    kept=$((kept + 1))
  fi
done < <(git -C "$repo" for-each-ref refs/heads --format='%(refname:short)')
echo "  delete $(wc -l < "$tmp/local_delete" | tr -d ' ') merged branch(es), keep $kept unmerged"

: > "$tmp/remote_delete"
if [ $remote -eq 1 ]; then
  echo "5/5 Branches on GitHub..."
  while read -r b; do
    in_scope "$b" || continue
    is_protected "$b" && continue
    if is_merged "$b" "$(git -C "$repo" rev-parse "refs/remotes/origin/$b")"; then
      echo "$b" >> "$tmp/remote_delete"
    else
      echo "  keep   origin/$b ($(why_kept "$b"))"
    fi
  done < <(git -C "$repo" for-each-ref refs/remotes/origin --format='%(refname:lstrip=3)' | grep -vx HEAD)
  echo "  delete $(wc -l < "$tmp/remote_delete" | tr -d ' ') merged branch(es) on GitHub"
else
  echo "5/5 Branches on GitHub: skipped (add --remote)"
fi

if [ $apply -eq 0 ]; then
  echo
  echo "Dry run: nothing changed. Run again with --apply to do it."
  exit 0
fi

echo
echo "Applying..."
while read -r path; do git -C "$repo" worktree remove "$path" && echo "  removed $path"; done < "$tmp/wt_remove"
git -C "$repo" worktree prune
if [ -s "$tmp/local_delete" ]; then
  xargs git -C "$repo" branch -D < "$tmp/local_delete" > /dev/null
  echo "  deleted $(wc -l < "$tmp/local_delete" | tr -d ' ') local branch(es)"
fi
if [ -s "$tmp/remote_delete" ]; then
  # In groups of 50, so one push stays small.
  xargs -n 50 git -C "$repo" push --quiet origin --delete < "$tmp/remote_delete"
  echo "  deleted $(wc -l < "$tmp/remote_delete" | tr -d ' ') branch(es) on GitHub"
fi
echo "Done."
