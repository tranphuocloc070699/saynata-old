# 02. Database (Postgres)

Postgres is the default. One database covers relational data, JSON (`jsonb`), full-text search,
queues (`SKIP LOCKED`) and vectors (`pgvector`). Add another store only when you have measured a need.

## Schema rules (from the Postgres wiki "Don't Do This")

| Do | Not | Why |
|---|---|---|
| `bigint generated always as identity` | `serial` | Standard SQL, and the sequence permissions are simpler |
| `timestamptz` | `timestamp` | It is an exact moment. `timestamp` without a zone is ambiguous |
| `text` + `check (length(x) <= n)` | `varchar(n)`, `char(n)` | Same speed. A check is easier to change |
| `numeric(12,2)` or integer cents | `money`, `float` for money | Rounding errors |
| `snake_case`, plural table names | `CamelCase` (needs quotes forever) | |
| `>= start and < end` | `between` for time ranges | `between` includes both ends |
| Index every foreign key column | Hoping Postgres does it | Postgres does not index FKs automatically |
| `not null` by default | Nullable "just in case" | Each null is an extra case in the code |
| `unique nulls not distinct` (PG 15+) | Plain `unique` on nullable columns | Plain unique allows many nulls |

Example: `stacks/backend/src/main/resources/db/migration/V1__create_notes.sql`.

## Migrations

- One tool owns the schema (Flyway in Java; Alembic or plain SQL files in Python). Hibernate is set
  to `ddl-auto=validate`, so it only checks the schema and never changes it.
- **Never edit a migration that is merged.** Add `V<n+1>`. (A Saynata rule that saved it more than once.)
- Make changes safe on big tables (expand, then contract):
  1. Add the new nullable column or table (fast, no long lock).
  2. Deploy code that writes to both the old and the new column.
  3. Backfill in batches.
  4. Switch reads to the new column, then add `not null`. In a later release, drop the old one.
- `create index concurrently` on big tables (in Flyway: a migration that is not in a transaction).
- Set `lock_timeout` (for example `set lock_timeout = '5s'`) in migrations, so a blocked migration fails
  fast and does not freeze the app.

## Queries

- Fix N+1 before it ships: load lists with one query (join / `in (...)` / projection).
- Use pagination with a cursor (`where id < :last order by id desc limit 50`), not a large `offset`.
- Run `explain (analyze, buffers)` on any query over a table that will grow. Turn on
  `pg_stat_statements` in production and look at the top 10 slow queries once a month.
- Use a pool size of about `(cores × 2) + disks`, not 100. More connections make Postgres slower.

## Testing

- Test against **real Postgres in Docker** (Testcontainers), the same major version as production.
  H2 or SQLite will hide real bugs. Saynata's backend tests use H2. In this kit's smoke test,
  real Postgres showed a missing `created_at` that a mock would not catch.
- Each test owns its data (a transaction rollback, or a fresh schema).

## Operations

- Backups: managed Postgres (Neon, Supabase, RDS, Crunchy) or `pgBackRest` / `wal-g` on a VPS.
  **Restore a backup to a test database every month.** A backup you never restored is not a backup.
- Use separate database users: the app user cannot `drop` tables, and the migration user is used only by deploys.

## Real examples

- Postgres wiki, *Don't Do This*: <https://wiki.postgresql.org/wiki/Don%27t_Do_This>
- GitLab, *Avoiding downtime in migrations*: <https://docs.gitlab.com/development/database/avoiding_downtime_in_migrations/>
- Braintree/PayPal, *Safe operations for high volume PostgreSQL*: <https://www.braintreepayments.com/blog/safe-operations-for-high-volume-postgresql/>
- `squawk`, a linter for Postgres migrations that you can run in CI: <https://squawkhq.com>
