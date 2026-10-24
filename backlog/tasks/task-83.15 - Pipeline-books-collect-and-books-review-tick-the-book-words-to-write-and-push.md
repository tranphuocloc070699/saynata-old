---
id: TASK-83.15
title: >-
  Pipeline: books collect and books review (tick the book words to write and
  push)
status: In Progress
assignee:
  - '@implementer'
created_date: '2026-10-24 18:42'
updated_date: '2026-10-24 19:04'
labels: []
dependencies:
  - TASK-83.14
parent_task_id: TASK-83
priority: medium
ordinal: 125000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
After books convert (TASK-83.14), the developer wants the new words and phrases from their books grouped (name, common, uncommon, rare, phrase, not on the word list), a local page to tick which ones to keep, and only the ticked ones written by Codex (collection write, free on the ChatGPT plan) and pushed to the VPS cache word_lookup (collection push). The book text stays on the Mac.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 books collect reads the ok .md files from books-report.tsv and adds new words and phrases to the collection table with a group, times seen, the books that use them and one example sentence; bundled, server-cached and already-collected words are skipped
- [ ] #2 Groups: name (always capitalised mid-sentence), common (Zipf >= 4), uncommon (3-4), rare (< 3), phrase (WordNet phrasal verb or idiom), not_on_list (not on the backend SCOWL list)
- [ ] #3 books review serves a page on localhost only: a tab per group, a checkbox per item, tick all in a group, Save writes the picks to pipeline.db; common starts ticked, names unticked; picks survive a restart
- [ ] #4 collection write and collection push only take book rows that were picked; other collection rows behave as before
- [ ] #5 books report prints counts per group and picked/written/pushed; tests cover the grouping, the skips, saving picks and the write/push filter
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR: https://github.com/tranphuocloc070699/saynata/pull/193 (into prefill/books-convert).
Test it. Goal: find new words and phrases in the books, tick them on a local page, write only the ticked ones with Codex and push them (free).
Steps (in pipeline/): 1) uv run pipeline books collect ~/Applications/Workspace/Books  2) uv run pipeline books review (tick, Save, restart: ticks stay)  3) uv run pipeline books report  4) uv run pipeline collection write --limit 20  5) uv run pipeline collection push (dry run)  6) uv run pipeline collection push --yes.
Expected: groups common/phrase ticked at first; only ticked book rows are written and pushed. Failure case: no DATABASE_URL gives a warning and skips the server check.
Automated: cd pipeline && uv run pytest (tests/test_book_words.py). 325 passed, 51 skipped.
<!-- SECTION:NOTES:END -->
