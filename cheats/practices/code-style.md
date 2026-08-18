# Code style

<!-- F-038 -->
Everything here is a **pattern**, not a constraint. Where this repo already does
it differently, this repo wins — consistency with the surrounding code beats
anything below. The constraints live in `practices/floor.md`.

## Comments

<!-- F-075 -->
**1–2 rows maximum, and none at all where the code speaks for itself.**

Write a comment only for what the code cannot say: a ticket reference, a
non-obvious *why*, an invariant, a workaround, a subtle gotcha.

**No comment on a function whose name already tells what it does.**

Forbidden:

- multi-line explanatory blocks;
- paragraph doc-comments above every function, constant and field;
- comments restating what the code does;
- comments narrating a change or a decision — "we do X because earlier Y…",
  "moved from Z", ADR-style prose. That belongs in the commit message or the
  design doc.

**This rule applies to agent-written code with full force.** Oversized comments
are treated as a defect in review, not a style preference. If anything, an agent
should write fewer comments than a human, because the temptation to narrate its
own reasoning is the exact failure mode.

Keep: build and generate directives, API-doc annotations, and citations of
external material quoted in place.

Some repos go further and run zero comments in a given language or layer.
`stack.md` records it if this one does.

## Helpers

<!-- F-076 -->
**Extract a function when it has more than one caller.** A single-use helper,
however well named, is often just indirection.

Stated as a pattern deliberately: a codebase whose house style is named
single-use helpers for readability, or one that extracts specifically to make a
unit testable, keeps its own style. Do not refactor toward this rule in a repo
that decided otherwise.

## Naming

Variable names match parameter semantics — if the parameter is `supportID`, the
fetched entity is `support`, not `actor`.

A string literal used in more than one place becomes a named constant.

## Documentation

<!-- F-088 -->
**Do not write documentation unless asked.**

The scope of that rule is *unrequested prose* — a README nobody wanted, an
architecture essay, a summary file at the end of a task.

It does **not** exempt you from keeping owned documents true. When a change makes
a touched component's README, API doc or runbook wrong, fixing it is part of the
change, not new documentation. The test is: did this document already exist and
does the change make it lie?

<!-- F-098 -->
Docs live **next to the code they describe** — per-directory READMEs, ADRs in the
repo — not in an external wiki that CI cannot see and reviews do not touch. A
doc outside the repo is a doc that goes stale without anyone noticing.
