---
name: explain-diff
description: Walk the developer through the current uncommitted diff (or a branch/PR diff) file by file - what changed, why, and what to check - so they can review every line. Use after each step, or when the user asks "what did you change", "explain the diff", or "/explain-diff".
---

# Explain the diff

Goal: the developer understands every changed line and knows where bugs could hide.

1. Get the diff: `git diff HEAD --stat` then `git diff HEAD` (for a branch: `git diff main...HEAD`).
   Include untracked files (`git status --short`).
2. Order the files the way a reader should read them: data/schema → logic → API → UI → tests → config.
3. For each file write:

```
### path/to/file.ext  (+12 −3)
What: one or two plain sentences.
Why: the reason, linked to the plan.
Look at: line ranges worth a careful read (edge cases, error paths, concurrency, SQL, security).
New idea for you: (only if the code uses a language feature or library API the developer may not know;
                   one short sentence + a link to the official docs)
```

4. Then a short "Risks" list: what could break, what is not tested, any assumption you made.
5. Then "How to try it": the exact commands or clicks.

Rules: plain English (B1-B2), short sentences. Do not paste whole files; quote only the lines you talk about.
If you notice a bug while explaining, say so first and offer the fix; do not hide it.
