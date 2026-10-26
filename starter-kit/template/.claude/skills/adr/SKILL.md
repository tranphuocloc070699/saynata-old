---
name: adr
description: Record an architecture decision (ADR) in docs/adr/ - the context, the options that lost, and the reason in the developer's words. Use when the developer picks a library, database design, API shape, hosting, or anything hard to undo, or says "/adr" or "write this decision down".
---

# Write an ADR

1. Find the next number: `ls docs/adr/` (files are `NNNN-short-title.md`).
2. Copy `docs/adr/0000-template.md` to `docs/adr/NNNN-<kebab-title>.md` and fill it in.
3. The reason must be the developer's own words. If they did not give one, write
   `Reason: not recorded` and ask them for it at the end of your reply.
4. List at least two options that lost, each with one line on why.
5. If this decision replaces an older ADR, set the old one's status to `Superseded by NNNN`.
6. Keep it under one screen. Link to code or docs instead of copying them.
