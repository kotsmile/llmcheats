---
name: migrate
description: "migrate: change a schema, backfill data, or move a version. Use for a prompt starting migrate:, or any request touching database schema, a data backfill, or a dependency/runtime major version."
---

# `migrate:` — full flow, always

<!-- F-011 -->
Schema migrations, data backfills and anything irreversible on real data are on
the trigger list. This never runs as a one-pass task, however small the SQL
looks.

## 1. Which kind of migration is this?

| Kind | Governing rule |
|---|---|
| Schema (DDL) | expand → migrate → contract, below |
| Data backfill | irreversible on real data; needs a dry run and a batch bound |
| Version move (runtime, dependency major) | the version barrier, below |

## 2. Schema: expand → migrate → contract

<!-- F-051 -->
Migrations are **backward compatible one release back** — the old code must run
against the new schema during rollout. That gives three steps, and **the default
deliverable of this workflow is the first one plus the plan for the other two.**

1. **Expand** — add the new column/table/index, nullable or defaulted. Old code
   is unaffected. Ships now.
2. **Migrate** — backfill, and start writing both. Ships now or next.
3. **Contract** — drop the old column, add the NOT NULL. Ships **only after**
   every running replica is on the new code.

Shipping all three in one release is the failure this sequence exists to
prevent: during rollout, old and new code are live simultaneously.

<!-- F-050 -->
**The migrate step runs before the new code serves, as its own step** — a
pre-deploy job, an init container, an `ExecStartPre=`, a one-shot compose
service. **Never on service boot.** N replicas racing DDL is a failure mode you
delete by keeping the step separate.

## 3. Write the migration

Use this repo's generator if it has one — `stack.md` names it. Never hand-write
the file where a generator exists; the naming and ordering are load-bearing.

<!-- F-063 -->
Never hand-edit an applied migration. Fix forward with a new one.

Index changes carry a justification comment naming the query they serve. A
partial index predicate must imply the `WHERE` clause of every query it serves.

<!-- F-078 -->
A new value in an enum-typed column is a **contract change** on that column, not
a routine migration. Raise it before writing it.

## 4. Rehearse it

- Run it against a scratch database seeded from a realistic dump.
- **Time it**, and check what it locks. A migration that takes an exclusive lock
  on a large hot table is an outage with a ticket number.
- Run the *down* path if this repo has one. If it does not, the rollback story
  is "roll forward with another migration" — say so explicitly in the plan.

## 5. Gates

Both open, and neither is skippable for a schema change:

- **DevOps:** ordering, locks, rollback, deploy-step placement.
- **Security:** if the migration touches PII, credentials, or an authz-bearing
  column.

## 6. Version moves

<!-- F-063 -->
Never hand-edit a lock file. Use the ecosystem's own command so the manifest and
the lock stay in sync; a hand-edited manifest produces a lock that no longer
describes what gets installed, and the divergence surfaces on someone else's
machine.

Watch for the **partial-install failure**: a batch of type errors in files
nobody touched usually means a stale module tree, not a code problem. Compare an
installed package's version against the declared one before debugging the code.

## 7. Hand-back

<!-- F-013 -->
```
Changed:      the migration file, the code that reads/writes the new shape
Ran:          the migration against a scratch DB, its timing, the suite
Not verified: production data volume, lock behavior under load — say which
Skipped:      the contract step, and what must be true before it ships
```

State explicitly which of expand/migrate/contract this delivers, and what has to
happen before the next one.
