---
name: step
description: Do one small, reviewable step of a task - plan, wait for approval, implement in under ~200 lines, test, then explain the diff. Use for any change bigger than a one-line fix, or when the user says "next step", "do the next part", or "/step".
---

# One reviewable step

The developer reads every line you write. A step is one idea they can review in about 10 minutes.

## 1. Plan (then stop)

Read the task, `CLAUDE.md`, and the code you will touch. Reply with:

```
Step: <one sentence>
Files:
  - path/to/file.ext — what changes (new / edit / delete)
Tests: which test proves it works (new or existing)
Size: ~N lines
Not in this step: <things you noticed but will leave>
Questions: <only real ones, or "none">
```

If the step is over ~200 lines, split it and plan only the first part. Then **stop and wait** for "go"
(or changes). Do not edit files before that.

## 2. Build

- Write the test first when the behaviour is clear; watch it fail; then write the code.
- Touch only the files in the plan. If you need another file, say so before editing it.
- Follow the patterns already in the folder. Match names, comment style, and error handling.
- No new dependency (use the `add-dependency` skill to ask).

## 3. Check

Run only the checks for the part you changed (`make check-<part>`, or the single test file).
Pipe long output through `| tail -40`. If something fails, fix it or say exactly what fails.

## 4. Hand over

Run the `explain-diff` skill. End with the suggested commit message
(Conventional Commits: `feat(notes): add search by title`) and the next step you propose.
Do not commit unless the developer asks you to.
