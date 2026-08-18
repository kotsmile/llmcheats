---
title: Web SPA patterns — routing, cookie auth and runtime config
summary: The admin SPA's lazy route tree and role gate, why the API base URL is resolved at runtime, and the class-merge helper that does not merge.
theme: frontend
keywords: [SPA, client routing, lazy, Suspense, protected route, allowed roles, cookie auth, session, runtime config, mounted config script, theme flash, inline script, class merge helper, conflict resolution, i18n, isolated project]
related:
  - frontend/feature-sliced-architecture.md
  - frontend/query-cache-and-invalidation.md
  - frontend/typescript-react-conventions.md
---

## Routing

Client-side routing with lazy loading. Every page is wrapped in `React.lazy()` + `Suspense`.

The tree is a public group (sign-in, sign-up, password recovery), a protected workspace with nested tabs and nested per-record layouts, and an admin area on its own top-level route. The root path redirects to the workspace or to sign-in.

Two rules, enforced in review:

- **Every new page must be lazy-loaded** in the router module.
- **Every new protected route must be wrapped** in the protected-route component with an explicit allowed-roles list.

The protected route checks in order: auth initialization → user profile loaded → role match → account activation. A signed-in user on a route their role is not allowed on is redirected by role, not shown an error.

## Cookie-based auth

The server manages session cookies; the client holds no token.

A single module calls the shared bootstrap in cookie mode, which wires the generated API client's refresh handling, the unauthorized callback, and the paths exempt from it. The app entry imports that module **for its side effect**, so the client is configured before the first query runs.

An auth hook exposes sign-in, sign-out, activation, the profile and derived role booleans. Role groupings and the role predicate live in the user entity slice, not in the components that branch on them.

## The API base URL is resolved at runtime

Resolution order:

```
window.__RUNTIME_CONFIG__.apiBaseUrl  →  the build-time env var  →  a relative default
```

**The runtime value wins on purpose.** The deployment mounts a config map over a small script in the built assets, so **one image serves every environment**.

Do not reintroduce a build-time-only base URL: it means one image per environment, and a wrong-environment build is indistinguishable from a right one until it talks to the wrong API.

In development the dev server proxies the API path and the WebSocket path to a configurable target.

## Theme without a flash

The theme is a class on the document element, restored from local storage by an **inline script in the HTML that runs before the app mounts**.

That inline script — not the store — is what prevents a flash of the wrong theme. The store must therefore not be the only writer of that class, and removing the script "because the store handles it" reintroduces the flash.

## The class-merge helper does not merge

Classes are composed with a local helper that is a plain **flatten-filter-join** — not the conflict-resolving merge utility from the ecosystem, which is not a dependency here.

It does **not** resolve utility conflicts:

```
cn("p-2", cond && "p-4")   // emits BOTH; CSS source order picks the winner
```

Use it for conditional classes. Express an override as a ternary that emits exactly one class.

## Internationalization

The i18n runtime is initialized from the shared translations package — resources, default language and supported list. Translations live in the package, never inline in a component.

Language comes from local storage, validated against the supported list, falling back to the default. The app entry imports the i18n module for its side effect before rendering.

Key types derive from the primary locale, so a key present in the secondary locale but missing from the primary is a **type error**, not a runtime fallback.

## Isolated web projects

A marketing site and a content site sit outside the shared-package graph on purpose.

| Aspect       | How the isolated projects differ                                           |
| ------------ | -------------------------------------------------------------------------- |
| Architecture | No FSD, no state management, no shared packages                            |
| Routing      | Path-based dispatch from the location, no router library                   |
| Tokens       | Their own theme block, not the shared token package                        |
| i18n         | A small context and a translations object, not the i18n runtime            |
| Styling      | Inline styles are acceptable for dynamic gradients and complex backgrounds |
| DOM          | Plain DOM elements are allowed — these are web-only                        |

A content site with its own lock file also builds from **its own directory as the Docker context**, not the workspace root — so it cannot reference anything above that directory, and its image build is defined on its own rather than shared.

Its image build pins snapshot flags, because a full snapshot of a module-tree root filesystem exceeds the build pod's memory limit and is killed.

Adding a string to an isolated project's translations means adding it to **both** locale objects and declaring the section's interface if it is new.
