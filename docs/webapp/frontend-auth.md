---
title: Authentication in the SPA
summary: The SPA holds no tokens — a cookie session with a three-way refresh verdict for product apps, backend-terminated OIDC for staff consoles.
keywords: [cookie session, HttpOnly, SameSite, 401, refresh, in-flight promise, transient, sign-out, OIDC, login page, return parameter, open redirect]
related:
  - webapp/security-authentication.md
  - webapp/security-frontend.md
  - webapp/frontend-data.md
  - webapp/frontend-structure.md
---

# Authentication in the SPA

Two models, by audience.

## Authenticating with a cookie session

Recommended for browser apps. The SPA holds **no tokens**. Sign-in sets an
HttpOnly, Secure, SameSite=Lax cookie; every request rides it automatically
(same origin). A grep of the codebase for `localStorage` should find only UI
preferences — theme, language, panel widths — never credentials.

## Handling 401 and refresh

The 401-refresh flow is the one subtle piece. Wrap `fetch` once:

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

## Delegating OIDC to the backend

For staff/console apps the SPA never talks to the identity provider and never
holds a token. The backend terminates OIDC
(`webapp/security-authentication.md`) and sets its own session cookie; the
frontend contributes:

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
