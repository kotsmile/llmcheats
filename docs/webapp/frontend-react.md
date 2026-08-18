---
title: React 19 conventions
summary: No hand memoization, StrictMode with lazy routes and a root error boundary, and the API client configured for side effects before the first query fires.
keywords: [React 19, useMemo, useCallback, memo, React Compiler, StrictMode, createRoot, lazy, Suspense, ErrorBoundary, side-effect import]
related:
  - webapp/frontend-structure.md
  - webapp/frontend-data.md
  - webapp/frontend-state.md
  - webapp/performance.md
---

# React 19 conventions

## Avoiding manual memoization

No manual `useMemo` / `useCallback` / `memo`. With the React Compiler enabled
they are noise (React 19 alone does *not* auto-memoize — enable the compiler if
you want that).

Without it, memoization is a measured optimization, never a habit: default to
none, and when a profiler shows a real hot spot, fix the data shape first.
Referential stability for effect dependencies is a correctness question —
restructure the dependency rather than memoizing around it.

## Standing conventions for React 19

- `<StrictMode>`, `createRoot`, `React.lazy` + `Suspense` for route splitting,
  a class `ErrorBoundary` at the app root.
- The API-client configuration module is imported **for side effects, first, in
  `main.tsx`** — the client must be configured before the first query fires.
- Server state in TanStack Query, client state in Zustand, and nothing
  duplicated between them.
