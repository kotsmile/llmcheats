---
title: Frontend structure — Feature-Sliced Design and routing
summary: Six FSD layers scaled to the app size, lazy routes, and a guard component whose check order is explicit; client-side guards are UX, not security.
keywords: [FSD, Feature-Sliced Design, layers, slices, barrel, React Router, lazy, Suspense, ProtectedRoute, guard, URL state, pushState]
related:
  - webapp/frontend-toolchain.md
  - webapp/frontend-auth.md
  - webapp/security-frontend.md
  - webapp/performance.md
---

# Frontend structure — Feature-Sliced Design and routing

## Layering with Feature-Sliced Design

Layers, top to bottom — **import only from the same or a lower layer, always
through a slice's public `index.ts`**:

```
src/
  app/        providers (router, query client), global styles, error boundary,
              the API-client side-effect module
  pages/      route-level components; thin — compose widgets/features
  widgets/    self-contained page sections (sidebar, header)
  features/   user-facing capabilities: the real screen bodies — tabs, modals,
              forms — each slice holding its own ui/ + model/ + api/
  entities/   domain types and pure mappers (API row → view row); no components,
              no queries
  shared/     ui/ (design-system primitives), api/ (client), lib/ (utils),
              config/, model/ (app-wide stores)
```

## Scaling the layer set to the app

A large product app uses all six. A small console legitimately flattens to
`app / features / widgets / shared` — screens live in `widgets/`, API types in
`shared/api/types.ts`, and one `features/queries.ts` holds every query/mutation
hook. Do not manufacture empty layers.

Other conventions: files under ~300 lines; alphabetically sorted imports;
components in `shared/ui/<Component>/` folders with an `index.ts` each and a
barrel `shared/ui/index.ts`.

## Routing and lazy-loading pages

Use **React Router v7** (declarative `<Routes>`) for a multi-page app. Every
page is lazy:

```tsx
const AdminPage = lazy(() => import("@/pages/admin"));
// one top-level <Suspense fallback={<Spinner/>}> around <Routes>
```

## Ordering the checks in a route guard

The auth guard is a wrapper component with an **explicit check order** —
initializing → authenticated → authorized → account-state:

```tsx
function ProtectedRoute({ children, allowedRoles }: Props) {
  const { profile, isInitialized } = useAuth();
  const location = useLocation();

  if (!isInitialized) return <Spinner />;                                    // 1
  if (!profile) return <Navigate to="/signin" state={{ from: location }} replace />; // 2
  if (!allowedRoles.includes(profile.role)) return <Navigate to="/" replace />;      // 3
  if (profile.activated === false) return <InactiveAccountOverlay />;        // 4
  return children;
}
```

Define role lists as named constants — never repeat a role array inline at each
route.

Client-side guards are **UX, not security**: the server decides authorization
on every request; a 403 from the "who am I" endpoint renders a dedicated
no-access screen instead of the shell.

## Keeping screen state in the URL

For a tiny console, a hand-rolled router is acceptable and instructive: a
discriminated-union `Route` type + `parseRoute(pathname, search)` /
`routePath(route)`, `useState<Route>` + a `popstate` listener. Two rules from
that pattern generalize to every SPA:

- **The URL is the source of screen state**: every screen's filled-in state
  rides in the query string so any screen is a pasteable link.
- `history.pushState` for navigations, `replaceState` for form-field edits —
  the back button must leave the form, not undo it a keystroke at a time.
