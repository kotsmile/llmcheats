---
title: PostgreSQL access, SQL style and migration flow
summary: How rows map to entities, the mandatory column formatting, when an index is justified, and why migrations run from a separate binary.
theme: backend
keywords: [SQL mapper, db tag, row struct, SQL formatting, index, foreign key, partial index, composite cursor, pagination, migration binary, sync hook, JSONB]
related:
  - backend/layered-architecture.md
  - devops/release-tagging-and-gitops.md
---

## Access layer

PostgreSQL with a thin SQL mapper — raw SQL, no ORM.

- Row structs carry `db:"column_name"` tags.
- Convert between row types and entities through explicit functions in the infra package.
- Complex JSONB columns get their marshalers in the same infra package.

## SQL formatting

Write column lists **vertically — one column per line**. Never pack several columns onto one line.

```sql
INSERT INTO users (
    id,
    email,
    role,
    created_at
)
VALUES (
    :id,
    :email,
    :role,
    :created_at
)
```

## Indexes

Do not add an index without a clear, justified need — **but** PostgreSQL does not index foreign key columns automatically. Only primary keys and UNIQUE constraints get one for free.

Any column set on a hot `WHERE` / `ORDER BY` path — per-user lookups, schedulers, gauges — needs an explicit index with a justification comment in the migration.

**A partial index predicate must imply the `WHERE` clause of every query it is meant to serve.**

## Cursor pagination

Use a composite cursor so equal timestamps stay stable:

```sql
(created_at, id) <= (...)
```

Select `limit+1` rows and return a next-cursor when more than `limit` came back. Cap `limit` server-side.

## Flat JSONB avoids migrations

Some domain data is deliberately stored as a flat JSONB column so that adding a field is code-only. Where that is the case, the entity's validator, its "requires a value for" predicate and its "has a value for" predicate must all be extended together — the schema will not catch a missed one.

## Migrations

Migration files live in a `migrations/` directory, embedded into the binary and consumed **only by the migrate command**.

Create one with the project's generator target — never write the file by hand.

## Applying migrations

**Local:** run the migrate command against the dev config.

**Production:** a GitOps sync-hook Job runs the migrate binary in an earlier sync wave than the deployment. The Job uses the same image as the service but invokes the migrate entry point.

**The service binary does not migrate on boot.** Never call the migration runner from the service's startup path — that pattern was removed deliberately, because it makes every replica a schema writer and couples rollout order to pod scheduling.

## Contract-level schema changes

A new value in an enum-typed column is a contract change on that column, not a routine migration. Discuss before writing it.

## Local infrastructure

The project ships a compose file and make targets to start and stop the local database and cache.
