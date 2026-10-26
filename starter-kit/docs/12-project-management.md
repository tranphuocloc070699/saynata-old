# 12. Managing and tracking the project

## Tasks

| Option | Good for | Note |
|---|---|---|
| **Backlog.md** (markdown in the repo) | Solo + agents | Agents can read and edit tasks with the CLI. Saynata uses it |
| **GitHub Issues + Projects** | Solo or a team, public repos | PRs close issues (`Fixes #12`); a board view; free |
| Linear | Teams that want speed | Good GitHub sync; paid for teams |

Pick **one**. For a new project, GitHub Issues is enough, and it keeps tasks, PRs and CI in one place.
Keep Backlog.md if you like agents managing tasks in files.

Each task has: a goal (one sentence), acceptance criteria (checkable), and "how to test".
An agent can only finish what you can check.

## Decisions: ADRs

Saynata's doc-7 (decisions with reasons, in your own words) is one of its best habits. In the kit
it is `docs/adr/NNNN-title.md` (`/adr` skill): context, decision, reason, options that lost, consequences.
Write one for every choice that is hard to undo (database, framework, auth, hosting, data model).

## Weekly 15-minute review

- Sentry: new and regressed issues.
- Uptime: incidents.
- Analytics: the five core events (doc 08). Is the funnel moving?
- LLM cost per day and per user (from the cost logs).
- Dependabot PRs: merge the green ones.
- `scripts/cleanup-branches.sh`: no branch older than 2 weeks without a reason.

## Docs that stay true

- Keep few docs, and keep them close to the code: `README.md` (run it), `CLAUDE.md` (rules), `docs/adr/`.
  Every extra doc must be kept true by hand, and Saynata's feature pages often went out of date.
- Generate what you can: the API docs from OpenAPI, the changelog from commits (release-please).
- A CI check for broken doc links (Saynata: `scripts/check_docs.py`) is cheap and catches rot.
