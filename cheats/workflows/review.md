---
name: review
description: "review: review a finished diff and return a verdict. Use for a prompt starting review:, or a request to review, audit or check a change, a branch, a PR or a range of commits before it merges."
---

# `review:` — the lens the flow does not hold

<!-- F-042 -->
This is not a stage of any flow. It is the independent read of a finished diff,
and it is the whole review path when there was no flow at all.

**Without subagents** — Codex, or any tool that cannot delegate — the same lens
is held by a deliberate second pass over the diff against the same list below.
That is a separate pass with fresh attention, not a glance while writing. The
gate happens either way; only the mechanism differs.

## 1. Bound the diff

Establish the range before reading anything: `git diff main...HEAD`,
`HEAD~3..HEAD`, a PR, or the working tree. Say which you reviewed.

<!-- F-069 -->
Count it. **~400 lines of non-generated change is the ceiling a reviewer can
read honestly.** Past that, say so and either review it in named parts or ask
for it split — a rubber stamp on 1,200 lines is worse than no review, because it
launders the diff as reviewed.

<!-- F-031 -->
Read the diff, plus the files it changes and their tests. Not the whole repo.
Generated files, lockfiles and vendored trees are noted as present and not read.

## 2. Read for these, in this order

Stop at the first two levels if they produce findings — a diff with a floor
violation does not need a style opinion.

**The floor** (`practices/floor.md`) — any hit is BLOCKING, no judgment call:

- a secret hardcoded, logged, or committed;
- SQL built by formatting or concatenation; an identifier or sort key
  interpolated rather than allow-listed;
- client input reaching the domain unvalidated;
- an authz check weakened, bypassed, or made optional;
- a test deleted or skipped, or a suppression added, to make the build green;
- an error swallowed;
- something destructive on shared state with no explicit go-ahead.

**Correctness and contracts:**

- Does it do what its message says, and only that? A behavior change smuggled
  into a refactor is a finding (F-042 territory — the commit is not revertable
  as a unit).
- A published contract changed without its consumer in the diff: a
  request/response shape, an event payload, an exported signature, a generated
  client.
- <!-- F-051 -->A migration that is not backward compatible one release back, or
  an expand and a contract shipping together.
- Error paths: are failures handled or returned, and does the status/reason
  mapping still hold?

**Tests** (`practices/testing.md`):

- <!-- F-015 -->A bug fix with no test that reproduces the bug.
- <!-- F-077 -->A test asserting the shape of the implementation rather than a
  behavior — it will be deleted the first time it is inconvenient.
- <!-- F-079 -->A test added only because code changed. Say so; it is a cost.

**Fit with this repo** (`stack.md`):

- <!-- F-038 -->Does it follow the conventions **this repo** already uses? A diff
  that imports the reference's patterns over a codebase that decided otherwise
  is a finding, not an improvement.
- Conventions recorded in `AGENTS.md` that this diff breaks.

## 3. Do not fix while reviewing

Reviewing and repairing are different jobs and mixing them destroys both: the
author loses the finding, and nobody reviews the repair.

Report. Fix only if asked, and then as its own change.

## 4. Verdict

<!-- F-029 -->
Cap: **8 KB.** Over it, the diff was too big — say that instead of writing more.

One line per finding: **file · what is wrong · what it breaks.** No file
contents, no restating the diff back.

```
Verdict: BLOCKED | APPROVED | APPROVED WITH FINDINGS
Reviewed: <range>, N files, ~M lines of non-generated change

BLOCKING
  api/handlers.go   sort key interpolated into the query — injection via ?sort=
  auth/session.go   the expiry check is now `>=`; a token is valid one tick past expiry

FINDINGS
  service/order.go  no test for the cancelled→refunded transition
  web/cart.tsx      manual useMemo; this repo is React 19 with the compiler

Not reviewed: 2,400 lines of generated client (api/gen/**)
```

<!-- F-071 -->
**A BLOCKED verdict is a requested-changes review, not a comment.** Where the
tooling has that distinction, use it — a blocking finding filed as a comment
gets merged past.

<!-- F-014 -->
Name what you could not assess: a path you could not follow, a behavior only
observable at runtime, a dependency you did not read.

An empty verdict is a real result. `APPROVED — no findings` is worth saying, and
inventing a nit to look thorough is the failure mode this cap exists to prevent.
