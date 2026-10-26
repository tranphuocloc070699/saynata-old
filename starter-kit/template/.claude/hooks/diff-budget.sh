#!/usr/bin/env bash
# PreToolUse hook for Edit/Write. Blocks the edit when the uncommitted diff is already bigger than
# DIFF_BUDGET changed lines (default 300), so every step stays small enough for a human to read.
# Exit 2 blocks the tool call and sends stderr to Claude.
#
# Raise it for one session:  DIFF_BUDGET=600 claude
# Turn it off for one session: DIFF_BUDGET=0 claude

budget="${DIFF_BUDGET:-300}"
[ "$budget" = "0" ] && exit 0

input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input")
cd "${cwd:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Staged + unstaged changes against HEAD, plus new untracked files (lock files do not count).
changed=$(git diff HEAD --numstat -- . ':(exclude)*lock*' ':(exclude)*.lock' 2>/dev/null \
  | awk '$1 != "-" { sum += $1 + $2 } END { print sum + 0 }')
untracked=$(git ls-files --others --exclude-standard -z | grep -zv 'lock' | xargs -0 -r cat 2>/dev/null | wc -l)
total=$((changed + untracked))

if [ "$total" -gt "$budget" ]; then
  cat >&2 <<EOF
Diff budget reached: $total changed lines (budget $budget).
Stop editing. Run /explain-diff so the developer can review this step, and wait for them to commit.
Then continue with the next small step. (The developer can raise the budget with DIFF_BUDGET.)
EOF
  exit 2
fi
exit 0
