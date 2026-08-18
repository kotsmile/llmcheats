---
title: Frontend client state with Zustand
summary: Client-only state lives in Zustand consumed through per-field selectors, and shared libraries export a store factory rather than a module-level singleton.
keywords: [Zustand, client state, store, selector, persist, devtools, factory pattern, createStore, useStore]
related:
  - webapp/frontend-data.md
  - webapp/frontend-auth.md
---

# Frontend client state with Zustand

Client-only state (theme, current selection, auth status) lives in **Zustand**;
anything fetched from the server does not — that is TanStack Query's job
(`webapp/frontend-data.md`).

## Declaring a store

```ts
interface ProfileState {
  profile: Profile | null;
  isSignedOut: boolean;
  setProfile: (profile: Profile | null) => void;
  markSignedOut: () => void;
}

export const useProfileStore = create<ProfileState>()(
  devtools(
    (set) => ({
      profile: null,
      isSignedOut: false,
      setProfile: (profile) => set({ profile, isSignedOut: false }),
      markSignedOut: () => set({ profile: null, isSignedOut: true }),
    }),
    { name: "profile" }
  )
);
```

## Consuming stores with selectors

Consume with **selectors, one field per call**:
`useProfileStore((s) => s.profile)`.

Persistence via the `persist` middleware for preferences (theme, language).

## Creating stores in shared libraries

A shared package must not own a module-level singleton. Export
`createXStore({ deps })` built on vanilla `createStore` + `useStore`,
re-attaching `getState`/`subscribe` on the returned hook so non-React code (the
API client's `onUnauthorized` callback) can read and act on the store.
