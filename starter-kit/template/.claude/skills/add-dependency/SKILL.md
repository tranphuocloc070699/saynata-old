---
name: add-dependency
description: Ask before adding a library, package, SDK, Gradle/Maven/npm/pip/SwiftPM dependency or GitHub Action. Gathers the facts the developer needs to decide. Use whenever a change would add or upgrade a dependency.
---

# Ask before adding a dependency

Every dependency is code the developer did not read. Ask first with this card, then wait:

```
Package: name @ exact version  (registry link)
Why: the problem it solves in this task
Without it: how much code we would write ourselves (~N lines), or which built-in API could do it
Health: last release date · weekly downloads or stars · open security advisories · licence
Size: install/bundle size (frontend: gzip size from bundlephobia/pkg-size)
Already have: any dependency in the repo that does the same job
```

Rules:
- Prefer the standard library and dependencies already in the repo.
- Pin exact versions (lock file committed). Never add a package published in the last 14 days.
- For GitHub Actions, pin to a full commit SHA with the version in a comment.
- After "yes", add it with the package manager command (never by hand-editing the lock file),
  and record big ones (frameworks, databases, SDKs) with the `adr` skill.
