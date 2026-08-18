# The floor

<!-- F-012 -->
Speed buys ceremony. It never buys these. A task that cannot be done without
breaking one is an **escalation, not a judgment call** — stop and say so.

1. **Secrets are never hardcoded, logged, or committed.**
2. **SQL is parameterized; client input is validated at the boundary.**
3. **No auth or authz check is weakened, bypassed, or temporarily disabled.**
4. **No test is deleted or skipped, and no `//nolint` / `# noqa` /
   `eslint-disable` is added, to make a build green.**
5. **Errors are handled or returned, never swallowed.**
6. **Nothing destructive touches shared or production state without an explicit
   go-ahead** — no drop, truncate, mass delete, force-push, or deploy.

This list does not scale down with the flow. It is identical under a thirteen-
stage feature and a two-minute chore.

## The four never-skips

<!-- F-039 -->
Whatever the maturity of the project:

- **Engineering constraints** — validated input, bound parameters, secrets out
  of code, errors handled, no authz weakened. Skipping them saves days and costs
  months.
- **Security practices for client secrets** — a young product is exactly the one
  that cannot survive a leak.
- **Observability** — you cannot operate what you cannot see.
  `practices/observability.md`.
- **Release speed** — the ability to ship a fix fast is itself a safety
  property. `practices/release.md`.

## Binding every dynamic value

<!-- F-081 -->
Every dynamic value reaches the database as a **bound parameter**. No SQL text
is built with string formatting, concatenation or interpolation, anywhere.

This is independent of how queries are written. A query builder or an ORM that
binds its values satisfies it; the same tool satisfies nothing the moment a
raw-fragment escape hatch takes a formatted string.

<!-- F-082 -->
Identifiers are not values: table names, column names, sort keys and sort
direction are **allow-listed against a fixed set of constants**, never
interpolated. Parameter binding cannot help you here, which is why it is a
separate rule.

## Validating input

<!-- F-083 -->
Three gates, and the third is the one that gets forgotten:

1. **Transport** — one chokepoint: size cap, reject unknown fields, reject
   trailing garbage, validate against the declared shape.
2. **Domain** — constructors re-validate their own invariants. A type that can
   only be built valid cannot arrive invalid.
3. **Automation input** — LLM tool calls, webhook payloads, queue messages get
   their own explicit parser with enum and bounds checks. **Never trust
   structured input because a schema was published.**

## Suppressions

<!-- F-064 -->
Never suppress a lint rule or a type error. No disable comments, no ignore
directives, no file-level opt-outs. Fix the root cause, or change the rule
deliberately and say that you did.

## Destructive flags

<!-- F-057 -->
**Never run the prune half of a sync tool.** Where two writers share a store and
one of them holds a "delete what I don't know about" flag, that flag will
eventually delete the other's work — the other writer's entries are, by
definition, not in the file being synced.

The plain push is safe; prune is the one that deletes. If a task genuinely needs
it, print the removal list and hand it to the operator before confirming.

This generalizes past secret stores: `terraform destroy`, `kubectl apply
--prune`, `rsync --delete`, a migration tool's "drop objects not in the schema"
mode. The shape is the same and so is the rule.

## Files that are not yours to edit

<!-- F-063 -->
- **Generated files.** Change the spec or the annotation and regenerate. A hand
  edit is silently reverted by the next run and produces a diff nobody can
  review.
- **Lock files and dependency manifests.** Use the ecosystem's own command. A
  hand-edited manifest produces a lock that no longer describes what will be
  installed, and the divergence surfaces on somebody else's machine.

`stack.md` names this repo's specific untouchable paths.
