---
title: Feature-Sliced Design across the apps
summary: The layer set, the import direction rule, and how a file-based router coexists with it in the mobile app.
theme: frontend
keywords: [FSD, feature-sliced design, layers, app, pages, features, entities, widgets, shared, public API, index.ts, import direction, file-based routing, composition root]
related:
  - frontend/typescript-react-conventions.md
  - frontend/mobile-stack-and-routing.md
  - frontend/web-app-patterns.md
---

## Layers

```
app / pages / features / entities / widgets / shared
```

Two rules, and they are the whole architecture:

1. **Import only from the same or a lower layer.**
2. **Every slice is reached through its own `index.ts` public API.** A deep import into a slice's internals is the violation that erodes the boundary.

The web admin app uses the full layer set. The mobile app uses a subset — entities, features, widgets, shared — because its routing layer is external (below).

## The mobile exception: routing sits beside the layers

The mobile app is a **hybrid**: a file-based router directory for routing, and FSD layers in the source directory.

```
app/     → file-based routing — NOT an FSD layer
src/     → entities / features / widgets / shared
```

The router directory holds route groups (auth, private, onboarding, public), nested tab groups and dynamic routes. The layers hold everything a route renders.

Practical consequence: a search scoped to the source root misses every screen. Grep both.

## Composition root

The `shared` layer owns a single bootstrap module that constructs the app: platform adapters, base URL, query client and a source marker header. It re-exports the auth store and token storage, which is how the rest of the app reaches them.

Everything that needs global wiring goes through that one module. Two composition roots is the failure this prevents.

## Marketing sites are exempt

An isolated marketing page has **no FSD, no state management and no shared packages**. Its structure is a flat split — components, full-screen sections, pages, i18n, static content, utilities — because a site with no domain model gains nothing from layers and loses readability.

Do not "upgrade" such a project to FSD. Do not let it grow a domain model without first deciding it is an app.

## Where a new file goes

| It is…                                               | Layer                                          |
| ---------------------------------------------------- | ---------------------------------------------- |
| A business domain model or its hooks                 | `entities`                                     |
| A user action or a flow                              | `features`                                     |
| A large composed UI block a screen assembles from    | `widgets`                                      |
| A route screen                                       | the router directory (mobile) or `pages` (web) |
| A primitive, a store, a hook, validation, i18n setup | `shared`                                       |

If a new component needs a deep import to be usable, the gap is in the exporting slice's `index.ts`, not in the importer.
