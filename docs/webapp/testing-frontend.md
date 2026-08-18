---
title: Frontend tests
summary: The SPAs rely on tsc -b plus ESLint as their check, with unit tests for pure logic in the platform's built-in runner and logic kept out of components.
keywords: [frontend test, tsc, ESLint, node:test, pure logic, lib, model, Testing Library, snapshot, reproduction test, browser walk]
related:
  - webapp/testing-strategy.md
  - webapp/frontend-structure.md
  - webapp/testing-ci.md
  - devflow/fast-flow.md
---

# Frontend tests

## Testing pure logic with the platform runner

Be honest about the trade-off the reference codebase makes: **the SPAs rely on
`tsc -b` + ESLint as their check**, and unit tests exist only for **pure
logic** — date/window rules, parsers, mappers, schedule computations — using
the zero-dependency Node built-in runner (Node ≥ 22.6 strips types from `.ts`
imports natively):

```ts
import assert from "node:assert/strict";
import { test } from "node:test";
import { bookingWindowAt } from "./bookingWindowRules.ts";

const at = (h: number, m = 0) => new Date(2026, 0, 15, h, m);

test("evening booking window is open 19:00–03:00 and closed the rest of the day", () => {
  // Assert — the window wraps midnight
  assert.equal(bookingWindowAt(at(19)).isOpen, true);
  assert.equal(bookingWindowAt(at(2, 59)).isOpen, true);
  assert.equal(bookingWindowAt(at(18, 59)).isOpen, false);
  assert.equal(bookingWindowAt(at(3)).isOpen, false);
});
```

## Keeping logic out of components

The discipline that makes this defensible: keep logic **out of components** —
in pure `lib/` and `model/` modules — so the testable surface is testable
without a DOM.

If you add component tests, add them for genuinely stateful composites (a
multi-step form), with Testing Library; do not snapshot-test markup.

## Reproducing a frontend bug

This is how the reproduction test in `webapp/testing-strategy.md` gets paid on
the frontend, so state it rather than improvising it: a bug in a screen is
usually a bug in a rule that should not have been inside a component, so pull
the rule into `lib/`/`model/` and let the failing test land there.

Only when nothing is left to extract — the defect is in markup, wiring, or a
library call — is there no unit to write, and then the fix reports the flow
walked in the browser and what it showed before and after. That is a narrower
carve-out than it looks: it never covers a rule, a computation, or a state
transition.
