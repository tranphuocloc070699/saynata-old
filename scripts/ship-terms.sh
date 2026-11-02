#!/usr/bin/env bash
# TASK-119: ship terms to production in one go. Run on the Mac from anywhere inside the repo:
#   scripts/ship-terms.sh
# 1. puts uncommitted changes aside (git stash) and remembers the current branch
# 2. merges origin/feature/local (and the rule branch) into main and pushes: the auto deploy starts, V39 runs
# 3. builds exports/terms/*.tsv from Wikidata (no LLM, free)
# 4. waits until the deploy has created the term table on the VPS (up to 15 minutes)
# 5. loads the terms (exports/terms/import_terms.sh, one transaction)
# 6. goes back to the old branch and restores the stashed changes
# Safe to run again: a merge that is already done is a no-op, and the import replaces the tables as a whole.
set -euo pipefail

SSH_HOST="${SSH_HOST:-vps_sieutoc}"
CONTAINER="${CONTAINER:-backend-postgres-1}"
EXTRA_BRANCH="${EXTRA_BRANCH:-claude/eager-shannon-r5wwt2}"

cd "$(git rev-parse --show-toplevel)"
start_branch="$(git branch --show-current)"
stashed=false

restore() {
  if [ -n "$start_branch" ] && [ "$(git branch --show-current)" != "$start_branch" ]; then
    git switch -q "$start_branch" || echo "Could not switch back to $start_branch." >&2
  fi
  if [ "$stashed" = true ]; then
    git stash pop -q || echo "Your changes are still in 'git stash list'; run 'git stash pop' by hand." >&2
  fi
}
trap restore EXIT

echo "1/5 Saving your uncommitted changes..."
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  git stash push -q -m "ship-terms: from $start_branch"
  stashed=true
  echo "    stashed (they come back at the end)."
else
  echo "    nothing to save."
fi

echo "2/5 Merging feature/local into main and pushing..."
git fetch -q origin main feature/local "$EXTRA_BRANCH"
git switch -q main
git merge -q --ff-only origin/main 2>/dev/null || git merge -q --no-edit origin/main
git merge -q --no-edit origin/feature/local
git merge -q --no-edit "origin/$EXTRA_BRANCH"
if [ ! -f pipeline/src/pipeline/terms.py ]; then
  echo "pipeline/src/pipeline/terms.py is missing after the merge. Stopped before pushing." >&2
  exit 1
fi
git push -q origin main
echo "    pushed $(git rev-parse --short HEAD). The deploy has started."

echo "3/5 Building terms from Wikidata..."
(cd pipeline && uv run python -m pipeline.terms > /dev/null)
echo "    $(($(wc -l < exports/terms/terms.tsv) - 1)) terms (see exports/terms/report.md)."

echo "4/5 Waiting for the deploy to create the term table (up to 15 minutes)..."
for i in $(seq 1 45); do
  if ssh "$SSH_HOST" "docker exec $CONTAINER psql -U app -d english_translation -Atc \"select to_regclass('public.term')\"" 2>/dev/null | grep -q term; then
    echo "    ready."
    break
  fi
  if [ "$i" -eq 45 ]; then
    echo "The term table is still missing after 15 minutes. Check the deploy: https://github.com/tranphuocloc070699/saynata-old/actions" >&2
    echo "Then run only the import: exports/terms/import_terms.sh" >&2
    exit 1
  fi
  sleep 20
done

echo "5/5 Loading terms into the VPS..."
exports/terms/import_terms.sh

echo "Done. Try https://saynata.com/?q=Nuxtjs"
