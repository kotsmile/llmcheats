---
title: Frontend data layer — API client and TanStack Query
summary: Server state lives in TanStack Query behind centralized keys, reached through one generated or hand-written client and one hook per file.
keywords: [API client, fetch, OpenAPI, generated client, ApiError, AbortSignal, TanStack Query, query keys, invalidation, staleTime, audited read, hooks]
related:
  - webapp/frontend-auth.md
  - webapp/frontend-state.md
  - webapp/security-audit-logging.md
  - webapp/performance.md
---

# Frontend data layer — API client and TanStack Query

## Choosing an API client

**Generated client (product apps).** Generate a typed fetch client from the
backend's OpenAPI spec (e.g. `@hey-api/openapi-ts`) — read the spec from the
backend's own build output so it cannot drift. Generated code is never
hand-edited. Wrap `fetch` once for auth/refresh (`webapp/frontend-auth.md`).

## Writing a hand-rolled API client

For small apps, ~40 lines is enough:

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

## Managing server state with TanStack Query

Server state lives in **TanStack Query**, never in a client-state store.

**Client defaults** — pick per data volatility:

```ts
new QueryClient({
  defaultOptions: { queries: { refetchOnWindowFocus: false, retry: 1 } },
});
```

`staleTime: Infinity` for immutable metadata; ~1 min for normal lists; per-hook
overrides where it matters.

## Centralizing query keys

Use a query-key factory (`@lukemorales/query-key-factory`) in one module; hooks
spread the key object:

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

For a small app a hand-rolled `keys` object of `as const` tuples is fine — the
point is *one* place that owns key shapes.

## Invalidating after mutations

Mutations invalidate by key, and after a state-changing decision invalidate
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

## Modeling audited reads as mutations

If a "read" writes an audit row (revealing a secret, opening a sealed record),
model it as `useMutation` on a POST — React Query must never re-fire it on
refocus, remount, or revalidation, and the result must never enter the query
cache.

## Organizing hooks one per file

In a shared data package: one file per hook (`useStaffClientsQuery.ts`,
`useSendMessageMutation.ts`), grouped in domain folders with barrel exports.
Components never call the API client directly — always through a hook.
