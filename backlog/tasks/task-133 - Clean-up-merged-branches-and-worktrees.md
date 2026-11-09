---
id: TASK-133
title: Clean up merged branches and worktrees
status: In Progress
assignee: []
created_date: '2026-11-09 09:17'
updated_date: '2026-11-09 09:18'
labels:
  - chore
dependencies: []
ordinal: 166000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The repo had 294 local and 236 remote branches (about 90% already merged) and 9 worktrees in 4 places, because GitHub kept PR branches after merge and squash merges hid merged branches from git. Decided 2026-11-09 (doc-7).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 GitHub deletes a PR branch on merge and allows only merge commits
- [x] #2 `scripts/clean-branches.sh` dry-runs by default and never touches main, feature/local, open-PR branches or dirty worktrees
- [x] #3 `scripts/merge-when-green.sh` removes the merged PR's local branch and worktree
- [x] #4 CLAUDE.md says where worktrees live and how to clean up
- [ ] #5 The repo is cleaned once with `--apply --remote`
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Script, merge hook, CLAUDE.md and doc-7 done. Dry run (2026-11-09): 279 local and 221 GitHub branches to delete, 2 clean worktrees to remove; 4 merged worktrees have only leftover changes (2 untracked caches/symlinks, 2 task notes now copied into TASK-102.3 and TASK-95).
<!-- SECTION:NOTES:END -->
