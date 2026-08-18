---
title: HTTP hardening
summary: Security headers and CSP at the proxy, a structural CSRF stance whose every leg matters, targeted rate limiting on auth paths, and generic 500s from the recover middleware.
keywords: [security headers, HSTS, nosniff, Referrer-Policy, COOP, CSP, CORS, CSRF, SameSite, 415, Origin, Sec-Fetch-Site, state-changing GET, rate limiting, 429, retry_after, panic, recover, metrics port]
related:
  - webapp/backend-transport.md
  - webapp/security-frontend.md
  - webapp/security-authentication.md
  - webapp/infrastructure.md
---

# HTTP hardening

## Setting security headers

One middleware, outermost after Recover:

```
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Strict-Transport-Security: max-age=31536000; includeSubDomains
Referrer-Policy: no-referrer        ← mandatory if any URL ever carries a token
Cross-Origin-Opener-Policy: same-origin
X-Permitted-Cross-Domain-Policies: none
```

Add a **Content-Security-Policy** for the SPA at the reverse proxy (the layer
that serves the HTML): `default-src 'self'` plus what the app genuinely needs.

## Configuring CORS

Only when a second origin is real; strict allowlist map; echo the matched
origin, never `*` with credentials.

## Defending against CSRF

The stance for a cookie-authenticated SPA is structural, and every leg matters:

- same origin (proxy), so no cross-origin XHR reaches the API with cookies;
- `SameSite=Lax` on every cookie;
- all state-changing routes are non-GET, and the backend **rejects any request
  whose `Content-Type` is not `application/json` (415, enforced in `ReadJSON` —
  `webapp/backend-transport.md`)**. This leg only holds if it is enforced:
  without the 415, a cross-site `<form enctype="text/plain">` posts without any
  preflight and can be shaped into valid JSON. With it, a cross-site sender
  must use JSON — which is not a "simple request", so it gets preflighted and
  blocked;
- checking `Origin` / `Sec-Fetch-Site` in middleware is a cheap additional leg
  worth adding;
- **therefore: never make a GET route state-changing.** `SameSite=Lax` still
  sends cookies on top-level cross-site GET navigations — a state-changing GET
  is your CSRF hole. Audit for it explicitly.
- `SameSite` is a cross-*site* control, not cross-origin: a sibling subdomain
  is same-site — never host untrusted content on one.
- Bearer-token clients (mobile, CLI) are outside CSRF entirely.

If any leg does not hold (cross-site deployment, form posts), add CSRF tokens.

## Rate limiting abuse-prone paths

At minimum, targeted counters on abuse-prone auth paths — login attempts per
account, code attempts, email sends per hour, resend cooldowns — atomic
INCR+EXPIRE in Redis (Lua or pipeline).

Keyed by account/email (credential-stuffing resistance); volumetric per-IP
limiting belongs at the ingress/proxy layer. Return 429 with `retry_after`. A
break-glass local-admin door gets a per-address lockout.

## Handling panics and debug detail

`Recover` middleware logs the stack and returns a generic 500 — the panic
message never reaches the client. Debug detail in error responses (cause,
location) is gated on an explicit per-session debug flag for staff.

## Isolating metrics and health endpoints

`/metrics` and health endpoints live on a separate listener/port with no public
route.
