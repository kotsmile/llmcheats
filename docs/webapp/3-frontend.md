# 3. Frontend: React SPA

## 3.1 Toolchain

- **Vite** + `@vitejs/plugin-react`, **TypeScript strict**, **Tailwind CSS 4**
  via `@tailwindcss/vite` (CSS-first config: `@theme` / `@source`; no
  `tailwind.config.js`, no `postcss.config.js`).
- `tsconfig`: `strict: true`, plus `noUnusedLocals`, `noUnusedParameters`,
  `noFallthroughCasesInSwitch`. `any` is prohibited — use `unknown` + type
  guards. No suppression comments (`@ts-ignore`, `eslint-disable`): fix the
  root cause.
- Path alias `@/*` → `src/*` (declared in both Vite and tsconfig, kept in sync).
- `build` script is `tsc -b && vite build` — the type check is part of the
  build, not a separate optional step.

**The dev proxy mirrors production paths:**

```ts
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } },
  server: {
    proxy: {
      "/api": "http://localhost:8080",
      "/auth": "http://localhost:8080",
    },
  },
});
```

Whatever the production reverse proxy forwards, the dev server forwards the
same — so cookies, redirects and relative URLs behave identically.

**Runtime config over build-time config.** Ship a `public/config.js` containing
`window.__RUNTIME_CONFIG__ = { apiBaseUrl: "" }` and let the deployment overlay
it (a mounted file, a templated asset). Resolution order:

```ts
export const env = {
  apiBaseUrl:
    window.__RUNTIME_CONFIG__?.apiBaseUrl   // deployment-provided — wins
    || import.meta.env.VITE_API_BASE_URL     // build-time fallback (dev)
    || "/api",                               // default: same-origin
};
```

One build artefact then serves every environment.

## 3.2 Feature-Sliced Design (FSD)

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

**Scale the layer set to the app.** A large product app uses all six. A small
console legitimately flattens to `app / features / widgets / shared` — screens
live in `widgets/`, API types in `shared/api/types.ts`, and one
`features/queries.ts` holds every query/mutation hook. Do not manufacture empty
layers.

Other conventions: files under ~300 lines; alphabetically sorted imports;
components in `shared/ui/<Component>/` folders with an `index.ts` each and a
barrel `shared/ui/index.ts`.

## 3.3 Routing and guards

Use **React Router v7** (declarative `<Routes>`) for a multi-page app.
Every page is lazy:

```tsx
const AdminPage = lazy(() => import("@/pages/admin"));
// one top-level <Suspense fallback={<Spinner/>}> around <Routes>
```

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

Define role lists as named constants — never repeat a role array inline at
each route.

For a tiny console, a hand-rolled router is acceptable and instructive: a
discriminated-union `Route` type + `parseRoute(pathname, search)` /
`routePath(route)`, `useState<Route>` + a `popstate` listener. Two rules from
that pattern generalize to every SPA:

- **The URL is the source of screen state**: every screen's filled-in state
  rides in the query string so any screen is a pasteable link.
- `history.pushState` for navigations, `replaceState` for form-field edits —
  the back button must leave the form, not undo it a keystroke at a time.

Client-side guards are **UX, not security**: the server decides authorization
on every request; a 403 from the "who am I" endpoint renders a dedicated
no-access screen instead of the shell.

## 3.4 Data layer

### API client

Two proven options:

**Generated client (product apps).** Generate a typed fetch client from the
backend's OpenAPI spec (e.g. `@hey-api/openapi-ts`) — read the spec from the
backend's own build output so it cannot drift. Generated code is never
hand-edited. Wrap `fetch` once for auth/refresh (see §3.6).

**Hand-written client (small apps).** ~40 lines is enough:

```ts
export class ApiError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
    this.name = "ApiError";
  }
}

async function request<T>(url: string, init?: RequestInit): Promise<T> {
  const res = await fetch(url, {
    ...init,
    // Plain-object headers only: spreading a Headers instance yields {}.
    // For FormData uploads use a separate helper — this JSON Content-Type
    // would break the multipart boundary.
    headers: { Accept: "application/json", "Content-Type": "application/json", ...init?.headers },
  });
  // Skip endpoints where 401 is a normal answer (the sign-in call itself),
  // or the login page would redirect to itself.
  if (res.status === 401 && !url.startsWith("/auth/")) {
    const back = window.location.pathname + window.location.search;
    window.location.href = `/login?return=${encodeURIComponent(back)}`;
    throw new ApiError(401, "unauthorized");
  }
  if (res.status === 204) return undefined as T;
  const body = await res.text();
  if (!res.ok) throw new ApiError(res.status, parseError(body) ?? `${url}: ${res.status}`);
  return (body ? JSON.parse(body) : undefined) as T;
}

export const api = {
  me: () => request<Profile>("/api/me"),
  search: (q: string, signal?: AbortSignal) =>       // abortable — the caller is a keystroke
    request<Suggestions>(`/api/search?q=${encodeURIComponent(q)}`, { signal }),
};
```

Always `encodeURIComponent` path/query parameters. Pass `AbortSignal` through
for type-ahead endpoints.

### TanStack Query

Server state lives in **TanStack Query**, never in a client-state store.

**Query keys are centralized.** Use a query-key factory
(`@lukemorales/query-key-factory`) in one module; hooks spread the key object:

```ts
export const staffKeys = createQueryKeys("staff", {
  clients: null,
  userDetail: (userId: string) => [userId],
});
export const queryKeys = mergeQueryKeys(staffKeys, orderKeys /* ... */);

export const useStaffClientsQuery = () =>
  useQuery({
    ...queryKeys.staff.clients,
    queryFn: async () => {
      const { data, error } = await getStaffClients();
      if (error) throw error;
      return data?.data;
    },
  });
```

(For a small app a hand-rolled `keys` object of `as const` tuples is fine —
the point is *one* place that owns key shapes.)

**Mutations invalidate by key**, and after a state-changing decision invalidate
**coarsely by prefix** — the screen that shows the result is usually not the
one the button was on:

```ts
onSuccess: (_data, variables) => {
  // TanStack Query v5: the argument is a FILTERS OBJECT. Always pass
  // { queryKey: [...] } explicitly — passing a bare key array (or a factory
  // object without unwrapping .queryKey) can silently match everything.
  queryClient.invalidateQueries({ queryKey: queryKeys.chat.messages(variables.chatId).queryKey });
  queryClient.invalidateQueries({ queryKey: queryKeys.chat.list.queryKey });
},
```

**Client defaults** — pick per data volatility:

```ts
new QueryClient({
  defaultOptions: { queries: { refetchOnWindowFocus: false, retry: 1 } },
});
```

`staleTime: Infinity` for immutable metadata; ~1 min for normal lists;
per-hook overrides where it matters.

**An audited or side-effectful read is a mutation, not a query.** If a "read"
writes an audit row (revealing a secret, opening a sealed record), model it as
`useMutation` on a POST — React Query must never re-fire it on refocus,
remount, or revalidation, and the result must never enter the query cache.

### One-hook-per-file

In a shared data package: one file per hook (`useStaffClientsQuery.ts`,
`useSendMessageMutation.ts`), grouped in domain folders with barrel exports.
Components never call the API client directly — always through a hook.

## 3.5 Client state: Zustand

Client-only state (theme, current selection, auth status) lives in **Zustand**;
anything fetched from the server does not.

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

- Consume with **selectors, one field per call**: `useProfileStore((s) => s.profile)`.
- Persistence via the `persist` middleware for preferences (theme, language).
- **Library stores use the factory pattern**: a shared package must not own a
  module-level singleton — export `createXStore({ deps })` built on vanilla
  `createStore` + `useStore`, re-attaching `getState`/`subscribe` on the
  returned hook so non-React code (the API client's `onUnauthorized` callback)
  can read and act on the store.

## 3.6 Authentication in the SPA

Two models, by audience:

### Cookie session (recommended for browser apps)

The SPA holds **no tokens**. Sign-in sets an HttpOnly, Secure, SameSite=Lax
cookie; every request rides it automatically (same origin). A grep of the
codebase for `localStorage` should find only UI preferences — theme, language,
panel widths — never credentials.

**The 401-refresh flow** is the one subtle piece. Wrap `fetch` once:

1. On 401 (excluding an explicit skip-list of endpoints where 401 is a normal
   answer), call the refresh endpoint.
2. **Collapse concurrent 401s onto one in-flight refresh promise** — an SPA
   firing five requests at once must cost one refresh, not five.
3. The refresh verdict is **three-way**, and the distinction is load-bearing:

```ts
type RefreshResult =
  | { status: "ok" }          // retry the original request
  | { status: "invalid" }     // server said 401/403 → session is dead → sign-out flow
  | { status: "transient" };  // network error / 5xx / timeout → surface the 401, do NOT log out
```

A flaky network must never destroy a valid session. Only an authoritative
"invalid" from the server clears local auth state.

Sign-out order: mark signed out in the store → cancel in-flight queries →
`queryClient.clear()` → fire-and-forget the logout request.

### OIDC via the backend (staff/console apps)

The SPA never talks to the identity provider and never holds a token. The
backend terminates OIDC (§5.1) and sets its own session cookie; the frontend
contributes:

- a `/login` page rendered **before the app shell mounts** (the shell's first
  act is an authenticated call — exactly the one that just bounced);
- sign-in as a plain link to `/auth/login?return=…`, sign-out as a link to
  `/auth/logout`;
- on 401 from the API: redirect to the app's own `/login` page, **not**
  straight into the IdP — an uninterruptible bounce can only ever offer the SSO
  door, and the day the IdP is down is the day you need the other one;
- an open-redirect guard on the `return` parameter:

```ts
function returnPath(): string {
  const raw = new URLSearchParams(window.location.search).get("return") ?? "/";
  return raw.startsWith("/") && !raw.startsWith("//") ? raw : "/";
}
```

## 3.7 Styling and design tokens

- **Tailwind 4, CSS-first.** The app's CSS entry is two imports: `tailwindcss`
  and the design-token theme.
- **Semantic tokens only.** Colors are `--color-background`, `--color-card`,
  `--color-primary`, `--color-destructive`… defined in `@theme` (light) and
  overridden under `.dark`. **Never hardcode hex values or raw palette scales
  in app code.**
- If tokens are shared across platforms, build them from a token source (JSON +
  Style Dictionary) emitting the Tailwind theme, dark/light variable sets, and
  typed JS tokens.
- Theme switching is a `dark`/`light` class on `<html>`, applied by an inline
  pre-React script in `index.html` (reads the persisted preference — no flash
  of wrong theme) and mirrored by a persisted store. In Tailwind 4 the `dark:`
  variant follows `prefers-color-scheme` by default — class-based theming
  needs one line in the CSS entry:
  `@custom-variant dark (&:where(.dark, .dark *));`
- A **small purpose-named type scale** beats a large generic one:
  `--text-row` (list rows, inputs), `--text-meta` (panel titles, qualifiers),
  `--text-caption` (chips, group headings). Name sizes for what they label.
- **Build the component library, not per-app components**: Button, Input,
  Modal, Card, Skeleton, EmptyState… If a primitive is missing, add it to the
  shared library, not to the app.
- If you compose classes with a `cn()` helper, know what yours does: a plain
  join does **not** resolve Tailwind conflicts (that's `tailwind-merge`);
  express overrides as a ternary emitting one class.

## 3.8 Forms

For apps with few forms, `useState` + a typed setter + an errors record is
sufficient and dependency-free:

```tsx
const [form, setForm] = useState<CreateOrderForm>(initialForm);
const [errors, setErrors] = useState<Partial<Record<keyof CreateOrderForm, string>>>({});

const setField = <K extends keyof CreateOrderForm>(key: K, value: CreateOrderForm[K]) => {
  setForm((prev) => ({ ...prev, [key]: value }));
  if (errors[key]) setErrors((prev) => ({ ...prev, [key]: undefined })); // clear on edit
};
```

Validate on submit against named constants (`TITLE_MAX_LENGTH`), mirror the
backend's limits. For form-heavy apps, `react-hook-form` + `zod` is the
standard upgrade path. Either way the backend re-validates everything — client
validation is UX only.

## 3.9 React 19 conventions

- **No manual `useMemo` / `useCallback` / `memo`.** With the React Compiler
  enabled they are noise (React 19 alone does *not* auto-memoize — enable the
  compiler if you want that). Without it, memoization is a measured
  optimization, never a habit: default to none, and when a profiler shows a
  real hot spot, fix the data shape first. Referential stability for effect
  dependencies is a correctness question — restructure the dependency rather
  than memoizing around it.
- `<StrictMode>`, `createRoot`, `React.lazy` + `Suspense` for route splitting,
  a class `ErrorBoundary` at the app root.
- The API-client configuration module is imported **for side effects, first, in
  `main.tsx`** — the client must be configured before the first query fires.
- Server state in TanStack Query, client state in Zustand, and nothing
  duplicated between them.
