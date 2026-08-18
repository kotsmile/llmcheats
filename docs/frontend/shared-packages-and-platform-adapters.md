---
title: Shared packages and platform adapters
summary: The cross-platform package set, the no-DOM rule that keeps it portable, the three-way refresh verdict, and the dual-output build config.
theme: frontend
keywords: [shared package, workspace, no DOM globals, react-native primitives, platform adapter, PlatformServices, secure storage, generated client, configureClient, RefreshResult, transient, tsup, dual output, external peers, design tokens]
related:
  - frontend/query-cache-and-invalidation.md
  - frontend/typescript-react-conventions.md
  - backend/code-generation.md
---

## The package set

Seven packages under one scope, consumed by the mobile app and the web admin app. Isolated marketing projects use none of them.

| Package | Owns | Build |
| --- | --- | --- |
| core | Types, translations, utilities | bundler |
| api | Generated fetch client | bundler + spec codegen |
| data | Query hooks, auth store, query keys | bundler |
| design-tokens | Colours, spacing, typography | token transformer |
| ui | Cross-platform components | bundler |
| platform-web | Web adapters | bundler |
| platform-mobile | Native adapters | bundler |

**After changing a package, rebuild it before testing in an app.** The apps consume build output, not source.

## No DOM globals

`window` and `document` are **forbidden** in every shared package, as is importing the web renderer. Enforced by lint rules scoped to the packages directory.

Reach browser and native APIs through the platform adapters instead.

## Cross-platform UI

The UI package uses **React Native primitives only** — a view instead of a div, a text node instead of a span, a pressable instead of a button, the native image instead of an img.

Platform splits use file extensions (`*.native.ts`, `*.web.ts`) plus a runtime platform check for narrow branches.

## The data-only package

The core package has **no runtime dependencies** and deliberately does not depend on the i18n runtime — it carries translation *data*, and the runtime is initialized by each app.

The primary locale **defines the translation type**; the secondary is checked against it. Adding a key means adding it to both, in that order, then rebuilding. Key format is dotted and hierarchical.

## The generated API client

```typescript
configureClient({
  baseUrl,
  getAccessToken?,          // token mode
  useCookieAuth?,           // cookie mode
  onUnauthorized,
  refreshTokens?,
  skipUnauthorizedForPaths?,
})
```

| Mode | Consumer | Config |
| --- | --- | --- |
| Token | Mobile | access-token getter + refresh callback |
| Cookie | Web admin | cookie flag + refresh callback |

It auto-retries a 401 after a successful refresh, and logs requests and responses in development.

### The refresh verdict is three-way, and the split is the point

| Verdict | Behaviour |
| --- | --- |
| ok, with a new token | Retry the request |
| invalid — the server answered 401/403, the session is dead | Call the unauthorized handler |
| transient — network error, 5xx, timeout | Return the original 401 **without signing out** |

A two-way verdict makes a flaky network indistinguishable from a revoked session, and wipes a refresh token that was still valid. That is the bug this type exists to prevent.

The generated client directory is never edited by hand — regenerate from the spec.

## Platform adapters

Both implement one interface declared in the core package:

```typescript
interface PlatformServices {
  storage: PlatformStorage         // ordinary key-value
  secureStorage: PlatformStorage   // credential storage
  notifications: PlatformNotifications
}
```

On the web, secure storage is **aliased to ordinary storage** — browsers have no native secure store. That aliasing is explicit rather than silent, so a caller storing a credential can see what it actually gets.

## Design tokens

A single source of truth in an interchange format, compiled by a token transformer.

Raw palette and scales live in a base directory; theme files map them onto the **semantic** tokens apps consume. Apps never reference the raw palette.

| Consumer | How |
| --- | --- |
| Web | A CSS import of the generated theme |
| Mobile | The generated preset in the styling config |
| JavaScript | Named exports |

Adding a token: edit the source JSON, rebuild the package, then use it through a class or an import.

## Build configuration

Every package except the token package uses the same bundler:

- **Dual output** — ESM and CJS, with declarations and source maps always on.
- The UI and native-platform packages mark the framework and its native peers **external**, so the app resolves a **single copy** of each. A bundled copy of the renderer is the classic duplicate-hook crash.

The token package uses a token transformer with custom formatters for each consumer target.
