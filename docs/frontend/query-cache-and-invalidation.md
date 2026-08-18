---
title: Query keys, cache invalidation and pull-to-refresh
summary: Why invalidation is declarative and prefix-based, why refetch is the wrong tool, and the overscroll-driven refresh that avoids a duplicated spinner.
theme: frontend
keywords: [query key factory, mergeQueryKeys, useInvalidate, composite scope, prefix invalidation, refetch, staleTime, cache key parameters, pull to refresh, RefreshControl, tintColor, contentInset, overscroll]
related:
  - frontend/shared-packages-and-platform-adapters.md
  - frontend/mobile-stack-and-routing.md
  - frontend/web-app-patterns.md
---

## Query keys

Per-domain factories from a key-factory library are folded into one object by a merge helper.

A hook **spreads the factory entry** rather than writing an array literal:

```typescript
...queryKeys.auth.me
```

An array literal at the call site is how two hooks end up with almost-identical keys that never invalidate each other.

## Hook shape

```typescript
export const useUserMeQuery = (options?) =>
  useQuery({
    ...queryKeys.auth.me,
    queryFn: async () => {
      const { data, error } = await getUserMe()
      if (error) throw error
      return data?.data
    },
    ...options,
  })

export const useSignInMutation = () =>
  useMutation({
    mutationFn: async (body) => {
      const { data, error } = await postSignIn({ body })
      if (error) throw error
      return data?.data
    },
  })
```

The generated client returns `{ data, error }` rather than throwing, so every hook unwraps it the same way.

## Declarative invalidation

One method per key domain, plus **composite scopes** that bundle what a whole screen renders:

```typescript
const invalidate = useInvalidate()

await invalidate.score()    // one domain — every query under its prefix
await invalidate.health()   // a screen's worth of domains
await invalidate.home()     // another screen's worth
await invalidate.all()      // nuclear option
```

Every method returns a promise, so it can be awaited in a refresh handler.

Under the hood each one invalidates by the domain's key **prefix**, which reaches every query under it — including queries with different cache-key parameters, and regardless of where in the component tree they live.

The composite scopes are the useful part: a screen names what it shows once, instead of every widget on it re-listing its own queries.

## Why not refetch

The cache key includes **every parameter** — filters, periods, limits — so each combination is a separate cache entry.

A refresh handler calling a local `refetch()` therefore refreshes only its own queries, **not** the ones owned by child components such as tabs and widgets. The result is a screen that looks refreshed at the top and is stale below.

Compounding it: the mobile app sets a multi-minute stale time, so a query younger than that will not refetch on mount. An explicit invalidate is required, not merely convenient.

## Pull-to-refresh

Use the shared pull-to-refresh hook together with the invalidator:

```typescript
const { isRefreshing, onRefresh, handleScrollEndDrag } =
  usePullToRefresh(() => invalidate.health(), 60, scrollRef)

<Animated.ScrollView ref={scrollRef} onScrollEndDrag={handleScrollEndDrag} bounces />
```

**There is deliberately no platform refresh control here.** iOS reads a transparent tint as "use the default", not "hide", so the native spinner leaks in beside the custom indicator — and no tint value expresses "none".

The hook detects overscroll from the scroll-end-drag event instead, and drives the scroll view's content inset for the hold and exit ramp. Without a ref it degrades gracefully: refresh still fires, only the exit animation is lost.

Any composition works as the callback:

```typescript
() => Promise.all([invalidate.score(), invalidate.task()])
```

## Symptom-to-cause table

| Symptom | Likely cause |
| --- | --- |
| Data stale after a mutation | Mutation did not invalidate, or invalidated a sibling prefix |
| Top of screen refreshes, widgets do not | A local `refetch()` instead of a domain invalidate |
| Nothing refetches on mount | Stale time not yet elapsed — invalidate explicitly |
| Two spinners on pull-to-refresh | A platform refresh control added next to the custom indicator |
