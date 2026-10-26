---
name: tidy-branches
description: List and delete merged or stale git branches (local and remote) so the repo does not collect hundreds of branches. Use when the user says "clean branches", "too many branches", or "/tidy-branches".
---

# Tidy branches

1. Run `scripts/cleanup-branches.sh` (dry run). It lists:
   - branches already merged into `main` (safe to delete),
   - branches with no commit for 30+ days and no open PR (stale; ask before deleting).
2. Show the developer the two lists, short.
3. After they say yes: `scripts/cleanup-branches.sh --delete` (merged only), or
   `scripts/cleanup-branches.sh --delete --stale` to also remove stale ones they approved.
4. Remind them once: GitHub → Settings → General → "Automatically delete head branches" keeps this from
   happening again.
