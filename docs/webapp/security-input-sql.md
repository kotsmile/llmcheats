---
title: Input validation and SQL injection
summary: Three validation gates from transport to entity to automation input, and one invariant — every dynamic value reaches the database as a bound parameter.
keywords: [input validation, defense in depth, ReadJSON, value object, tool input, webhook, SQL injection, bound parameter, placeholder, identifier allow-list, LIKE escaping, array binding]
related:
  - webapp/backend-transport.md
  - webapp/backend-entities.md
  - webapp/backend-infrastructure.md
  - webapp/ai-features.md
---

# Input validation and SQL injection

## Validating input at three gates

Defense in depth:

1. **Transport**: one `ReadJSON` chokepoint — body-size cap (1MB default),
   `DisallowUnknownFields`, single-JSON-value check, struct-tag validation
   (`webapp/backend-transport.md`). Set a smaller cap where the domain
   justifies it.
2. **Entity**: value-object constructors re-validate domain rules
   (`webapp/backend-entities.md`).
3. **Any tool/automation input** (LLM function calls, webhook payloads): its
   own explicit parser with enum and bounds checks. Never trust structured
   input because a schema was published.

## Binding every dynamic value

**Every dynamic value reaches the database as a bound parameter — no
exceptions, enforced by review and grep.** No SQL text is built with string
formatting, concatenation or interpolation anywhere in the codebase.

This is the invariant, and it is independent of how the query is written. A
query builder or an ORM that binds its values satisfies it; the same tool
satisfies nothing the moment a raw-fragment escape hatch takes a formatted
string. The reference codebase writes SQL by hand for reasons that are not
about injection (`webapp/backend-infrastructure.md`) — deviating from *that* is
an architecture choice, deviating from *this* is a vulnerability.

The two idioms:

- Positional placeholders `$1..$n`; variable-length IN-lists stay parameterized
  via array binding: `where subject = any($1)` with `pq.Array(values)`.
- Named parameters bound from tagged structs for wide INSERT/UPDATE.

Query text is `const`. `LIKE`/`ILIKE` user input goes through an escape helper
for `%`/`_`.

## Allow-listing identifiers and sort keys

No identifier (table, column, sort key, direction) is interpolated either: map
client-supplied sort and filter keys to a fixed allow-list of constants before
they touch a query.
