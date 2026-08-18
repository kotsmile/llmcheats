---
title: Mobile app — stack, routing, storage and keyboard handling
summary: The React Native stack, the file-based route tree, synchronous key-value persistence, and the three-layer keyboard approach.
theme: frontend
keywords: [react native, managed SDK, new architecture, file-based routing, tabs, synchronous key-value storage, persisted store, keyboard animation, keyboard-aware scroll view, performance list, inverted list, form resolver, schema validation, i18n]
related:
  - frontend/mobile-ui-pitfalls.md
  - frontend/feature-sliced-architecture.md
  - frontend/query-cache-and-invalidation.md
  - frontend/shared-packages-and-platform-adapters.md
---

## Stack

React Native with the New Architecture enabled, on a managed framework SDK.

| Concern       | Library                                                                         |
| ------------- | ------------------------------------------------------------------------------- |
| Routing       | The framework's file-based router with typed routes; its version tracks the SDK |
| Styling       | Utility classes for React Native, plus the shared design-token preset           |
| Animation     | A native-driven animation library                                               |
| Server state  | A query/cache library                                                           |
| Client state  | A small store library, persisted through synchronous key-value storage          |
| Storage       | A synchronous key-value module replacing the async storage API                  |
| Keyboard      | A native keyboard-animation library                                             |
| Graphics      | A GPU-accelerated 2D canvas, plus a chart library built on it                   |
| Menus         | A native context-menu wrapper                                                   |
| Lists         | A high-performance list component                                               |
| Notifications | Push tokens plus locally scheduled notifications                                |
| Forms         | A form library with a schema-validator resolver                                 |
| i18n          | An i18n runtime fed by the shared translations package                          |

## Commands

The project's build task compiles the shared packages the app imports; its test task runs lint, a type check and the test suite. The framework's own commands run the dev server, the simulators and a physical device, and perform a native prebuild.

The test suite requires the pinned minimum Node major (for glob support and type stripping) and is **not run by CI today** — only locally.

## Native dependencies

Always install a native module with the framework's own install command, never the plain package-manager add. It selects the SDK-compatible version and avoids linking issues.

## Route tree

The router directory is organised by group:

| Group            | Contents                                                          |
| ---------------- | ----------------------------------------------------------------- |
| root layout      | Gesture handler, keyboard provider, query client, safe area       |
| auth group       | Login, signup, activation, password reset, email verification     |
| private group    | The signed-in app, containing the tab group and stack screens     |
| tab group        | One screen file per tab                                           |
| onboarding group | The onboarding flow                                               |
| public group     | Routes reachable without a session, e.g. email verification links |

Dynamic routes carry the id in the filename. Two conversation screens exist and are genuinely different: one streams model output with tool cards and quick replies, the other is human-to-human with offline support and file uploads.

## Tabs are declared twice

The tab layout declares one trigger per screen file in that directory — **adding a tab means adding both** the file and the trigger.

Icons come from the platform's native symbol set; labels come from i18n. A route outside the tab group is a stack screen, not a tab.

## Composition root

A single bootstrap module constructs the app from the platform adapters, base URL and query client, and sets a source marker header on every request. It exports the auth store and token storage.

Mobile uses **token mode** — an access-token getter plus a refresh callback.

## Persisted stores

Every persisted store uses the synchronous key-value storage, which is roughly an order of magnitude faster than the async API it replaced:

```typescript
export const useMyStore = create<MyState>()(
  persist((set) => ({ ... }), {
    name: 'my-store',
    storage: createJSONStorage(() => kvStorage),
  }),
)
```

Note the current major version uses a **factory function**, not a constructor.

## Keyboard handling — three layers

| Layer                 | Mechanism                                                                   |
| --------------------- | --------------------------------------------------------------------------- |
| Root layout           | A keyboard provider wrapping the entire app                                 |
| Auth and form screens | A keyboard-aware scroll view replacing the avoiding-view + scroll-view pair |
| Chat screens          | An animated keyboard hook driving an absolutely positioned input            |

```typescript
const { height: keyboardHeight } = useReanimatedKeyboardAnimation()
const inputStyle = useAnimatedStyle(() => ({
  bottom: Math.max(-keyboardHeight.value, safeBottom),
}))
```

**Never** use the framework's built-in avoiding view — it fights the native animation and produces the jump it is meant to prevent.

## Lists

| Component            | Use for                                                                                                                       |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| The performance list | Non-inverted lists — conversation lists, pickers. The current major measures items itself, so there is no estimated-size prop |
| The stock list       | **Inverted** message lists — the performance list's inverted mode misbehaves with chat scrolling                              |

## Forms

A form library with schema resolvers, and the schemas kept in a shared validation directory rather than beside the screens — the same schema usually validates in two places.

## i18n

Initialized once in the shared layer and imported by the root layout. Language is auto-detected from device locale. Types come from a module augmentation, so a missing key is a type error rather than a runtime fallback. Translations live in the shared package, never inline in a component.

## Key rules

- React Native primitives only — no DOM elements.
- Utility classes for styling; no inline styles except dynamic theme values.
- A safe-area view with an explicit `edges` prop on every screen.
- A refresh control on every scrollable screen whose data can change, tinted from the theme.
