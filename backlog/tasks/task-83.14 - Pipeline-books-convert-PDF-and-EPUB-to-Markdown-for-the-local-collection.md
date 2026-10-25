---
id: TASK-83.14
title: 'Pipeline: books convert (PDF and EPUB to Markdown, for the local collection)'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-24 18:35'
updated_date: '2026-10-24 18:35'
labels: []
dependencies: []
parent_task_id: TASK-83
priority: medium
ordinal: 124000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The developer has a folder of about 85 books (PDF, EPUB) and wants the words in them that are not in the database yet, written for free by the local Codex collection overnight (TASK-83.9). The admin Sources page (TASK-108) only reads .txt/.md, so the books need converting first. Conversion is slow and some books will not work (scanned PDFs give no text, some books are Vietnamese), so it is its own resumable step with a report. Book text is copyrighted: it stays on the Mac, outside the repo.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 uv run pipeline books convert <folder> writes one .md per .pdf/.epub into an output folder outside the repo, keeping the subfolders
- [ ] #2 A book that already has its .md is skipped, so the command can be stopped and run again
- [ ] #3 A report marks each book ok, empty (no text, for example a scanned PDF), not_english (mostly Vietnamese letters) or failed, with its word count
- [ ] #4 Tests cover the skip, the empty and not_english checks, and a failed conversion
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. New module src/pipeline/books.py: find .pdf/.epub under a folder, convert each with markitdown (injectable converter for tests), write <book>.md next to the book (or under --out, same subfolders) through a .part file so a killed run never leaves half a file.
2. Skip a book whose .md exists, but still classify that .md for the report.
3. Classify: empty (< 1000 English words), not_english (> 5% of letters are non-ASCII, e.g. Vietnamese), failed (converter error, no .md), else ok. Report TSV books-report.tsv + a printed summary.
4. CLI: uv run pipeline books convert <folder> [--out DIR]. Dependency markitdown[pdf].
5. Tests in tests/test_books.py with a fake converter.
<!-- SECTION:PLAN:END -->
