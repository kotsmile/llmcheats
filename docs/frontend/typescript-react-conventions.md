---
title: TypeScript and React conventions
summary: The strictness, styling, state and dependency rules that apply to every React project in the repo.
theme: frontend
keywords: [typescript strict, any, unknown, generics, react 19, useMemo, useCallback, memo, utility classes, no comments, file size, import order, client store, query cache, design tokens, node version]
related:
  - frontend/feature-sliced-architecture.md
  - frontend/shared-packages-and-platform-adapters.md
  - tools/dependency-management.md
---

## TypeScript

- Strict mode everywhere.
- **`any` is prohibited** — use `unknown` plus type guards.
- Descriptive generic parameters: `TData`, `TValue`.
- `T[]`, not `Array<T>`.
- Named interfaces, not inline `Array<{...}>`.

## React 19

**No manual `useMemo`, `useCallback` or `memo`.** The compiler handles memoization; hand-written memoization is noise that goes stale.

## Code style

- Utility-class styling only — no plain CSS files, no inline styles except dynamic values read from the theme.
- **No code comments** in frontend apps.
- Files under 300 lines.
- Alphabetically sorted imports.
- SOLID without over-engineering.

## State

| Kind         | Library               |
| ------------ | --------------------- |
| Client state | A small store library |
| Server state | A query/cache library |

Query keys come from a key-factory library, defined once in the shared data package. A hook **spreads** the factory entry rather than writing an array literal.

## Design tokens

**Never hardcode a design value** in an app that consumes the shared token package. Colours, spacing and typography all come from tokens, which carry the light/dark split.

Two deliberate exceptions exist — an isolated marketing site with its own theme block, and the internal-tooling SPAs with their own token set. Both are documented where they live.

## Path aliases

| Alias                    | Resolves to                 |
| ------------------------ | --------------------------- |
| the shared-package scope | each package's build output |
| `@/*` inside an app      | that app's source root      |

Always use the alias instead of a relative path for source-root imports.

## Finding symbols

"Who uses this symbol" is a **language-server** question — find-references, go-to-definition — not a grep question. Grep mixes fields, variables, serialization tags and comments into one answer.

A cold index returns a plausible **incomplete** result, so request document symbols on the declaring file first to warm it.

Note that a file-based router directory sits **beside** the source root, not inside it: a search scoped to the source root silently misses every route screen.

## Dependencies

Adding a dependency, the lock-file rule and the runtime version barrier that causes phantom type errors: `tools/dependency-management.md`.

## After changes

- Check the console and server logs for errors.
- Run the lint task.
- Test before committing.
