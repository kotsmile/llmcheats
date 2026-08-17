# 5. Security

## 5.1 Authentication

### First-party JWT (product apps: end-user browser + mobile)

- The API issues its own access + refresh tokens (HMAC-signed JWT is fine for
  a single-service issuer).
- **Browser: HttpOnly cookies. Mobile/CLI: `Authorization: Bearer`.** The
  middleware extracts **cookie first, then header** — one code path, both
  clients.
- The refresh cookie is scoped with `Path=/api/user/refresh` — the path **as
  the browser sends it** (proxy prefix included) — so it rides only to the one
  endpoint that needs it.
- Refresh tokens are **single-use**, tracked by JTI in Redis; account deletion
  and password change revoke all JTIs.
- `AuthOptional` (for public-or-private resources) **fails closed** on a
  present-but-invalid token: only a credential-less request proceeds
  anonymously.

### OIDC via the backend (staff/console apps)

The backend terminates OIDC against the IdP (e.g. Keycloak) and issues its own
session cookie. Hard-won rules:

- **The session cookie is encrypted (AEAD), not merely signed** — it carries
  the refresh token. AES-256-GCM, random nonce per seal, key derived from
  configured secret. HttpOnly + Secure + SameSite=Lax.
- **Version the cookie layout.** Refuse an older version rather than decode it
  with missing fields — a cookie with no roles field would otherwise decode as
  "this user has no roles", indistinguishable from a real answer.
- **Freshness model**: claims copied into the cookie are trusted until the
  access token's expiry, then a refresh grant re-asks the IdP. Distinguish
  three outcomes: grant refused → session dead, back to login; IdP unreachable
  → serve stale claims until absolute expiry with a short retry backoff;
  success → reseal. Collapse concurrent refreshes with singleflight (keyed on
  a digest of the refresh token, on a `WithoutCancel` context so one client's
  hangup doesn't fail the coalesced waiters).
- **Token verification**: JWKS via OIDC discovery; check signature, issuer,
  expiry. If your IdP doesn't reliably populate `aud` for API access tokens,
  verify the authorized-party claim (`azp`) against an explicit client
  allowlist instead — the check moves, it must not disappear. Strip empty
  strings from the allowlist at construction so an unset env var can't become
  a wildcard.
- **OAuth flow hardening**: `state` in an HttpOnly cookie compared against the
  callback query; open-redirect guard on `return` paths (`startsWith("/") &&
  !startsWith("//")`) on both login and callback; logout revokes the refresh
  token at the IdP's end-session endpoint, best-effort, cookie cleared
  regardless.
- **Never fail open.** If auth configuration is missing, refuse to start in
  production. A dev pass-through authenticator (fixed identity + roles) is
  invaluable for tests and local work, but it must be impossible to reach in a
  production build path without an explicit, loud opt-in.

### Machine tokens (service-to-service, CLI)

Format `prefix_<public-id>_<secret>`: 8-byte id + 32-byte `crypto/rand`
secret. Store **plain SHA-256** of the secret — a slow KDF defends
small-keyspace passwords; a 256-bit random secret has nothing to iterate
against. What matters: plaintext never stored, comparison constant-time
(`subtle.ConstantTimeCompare`). Check order is cheapest-first and
fail-early: shape → stored hash → expiry → *only then* any upstream identity
resolution, so unauthenticated garbage never reaches your IdP.

## 5.2 Authorization

Layered, from coarse to fine:

1. **Route-level role gate** (middleware): "may this class of user enter this
   door at all". Answers **403, never a redirect** — redirecting an
   authenticated-but-unauthorized user to login is an infinite loop with a
   friendly face. Stack it inside the auth middleware so a misordered route
   denies everyone — the safe direction for a wiring mistake.
2. **Resource-level decision in the service**, against ownership/delegation
   data, in **one place** (`mustSee` / `mustAdminister` helpers). The service
   is what fetches — a route added tomorrow that forgets to ask returns
   nothing, not everything. Router-level "GET is read, POST is write" is not
   sufficient when a POST can be semantically a read (see audited reads).
3. **Operation-level permission checks in entities** (`actor.CheckPerm(...)`),
   for rules that depend on both actor and target state.
4. **Field-level response filtering** by viewer role (§2.5,
   `webapp/2b-backend-transport.md`).

Patterns that generalize:

- **Roles as structured strings** `<system>:<selector>:<access>` — parse them
  into a typed `Actor` **once at the transport boundary**; keep derived fields
  unexported ("a field anybody could set is a field somebody eventually sets
  from a request"). The decision is an ordered comparison of access levels
  (`none < read < write`), taking the maximum over matching grants.
- **Group hierarchies: expand the caller's side, not the grant's.** If a grant
  on a parent group must cover subgroups, expand the *user's* group list into
  its ancestor paths, then match with exact string equality — which stays
  indexable in SQL (`subject = any($1)`), where a prefix-match would be
  neither indexable nor honest.
- **Authorization-relevant filters live in SQL**, not Go: an expired grant
  must not reach the decision at all — a filter the caller can forget is a
  filter somebody eventually forgets.
- For an approval/change-management system: keep the policy **in a reviewed
  file in version control, not a database table** the system itself can edit.
  Embed a default so a failed config mount can't silently degrade; refuse a
  policy that renders any request kind unapprovable; when a template
  placeholder has nothing to fill it, **drop the rule rather than widen it**.

## 5.3 Input validation

Defense in depth, three gates:

1. **Transport**: one `ReadJSON` chokepoint — body-size cap (1MB default),
   `DisallowUnknownFields`, single-JSON-value check, struct-tag validation
   (§2.5, `webapp/2b-backend-transport.md`). Set a smaller cap where the
   domain justifies it.
2. **Entity**: value-object constructors re-validate domain rules.
3. **Any tool/automation input** (LLM function calls, webhook payloads): its
   own explicit parser with enum and bounds checks. Never trust structured
   input because a schema was published.

## 5.4 SQL injection

**100% parameterized queries — no exceptions, enforced by review and grep.**
No SQL built with string formatting anywhere in the codebase. The two idioms:

- Positional placeholders `$1..$n`; variable-length IN-lists stay
  parameterized via array binding: `where subject = any($1)` with
  `pq.Array(values)`.
- Named parameters bound from tagged structs for wide INSERT/UPDATE.

Query text is `const`. `LIKE`/`ILIKE` user input goes through an escape helper
for `%`/`_`.

## 5.5 Secrets

- **Delivery**: secret manager → deployment secret → env var → `${VAR}` in the
  config file. The app never fetches secrets itself and never reads env vars
  directly (§2.7, `webapp/2b-backend-transport.md`).
- **Never log the config.** Also: expose the list of secret *values* to a
  response-redaction middleware that replaces any occurrence in a JSON
  response with `[REDACTED]` — with a minimum-length floor (~12 chars) so a
  dev default like `postgres` doesn't shred responses. Skip it for streaming
  routes.
- **Encryption at rest** for sensitive user content (private chat, health
  data): AES-256-GCM, random nonce per message stored beside the ciphertext,
  AEAD tag as tamper detection. One shared cipher instance for the domain so
  key rotation touches one place. Validate key length at startup
  (16/24/32 bytes), not first use.
- Secret-bearing responses set `Cache-Control: no-store, max-age=0`.
- On the client: revealed secret values live in component state and die with
  it — never in the query cache, never in any storage (§3.4,
  `webapp/3-frontend.md`).

## 5.6 Audit logging

For any system that manages access, money, or secrets:

- **Append-only by construction, not convention**: the repository type has no
  update and no delete method. "An audit log with an update path is one whose
  contents are an opinion." Retention is a scheduled age-based DELETE at the
  ops layer, not a code path the type exposes.
- **Audit reads, not just writes** — for sensitive material the question is
  "who looked at this", far more often than "who changed it".
- **Audit before disclosure, and a failed audit write fails the action**: the
  audit row is written before the sensitive payload is fetched; a disclosure
  nobody can attribute is worse than one that did not happen.
- Record **what** was touched (resource, keys, a structural diff of
  operations), never the payload values.
- Model audited reads as POST so a page refresh doesn't replay them.
- Cap and filter audit feeds **in SQL** so the limit counts rows the caller
  actually receives.
- Prefer auth mechanisms that put a **person's** name in the log even for CLI
  access (device-grant tokens over shared bot credentials).

## 5.7 HTTP hardening

Headers (one middleware, outermost after Recover):

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

**CORS**: only when a second origin is real; strict allowlist map; echo the
matched origin, never `*` with credentials.

**CSRF stance** for a cookie-authenticated SPA — structural, and every leg
matters:

- same origin (proxy), so no cross-origin XHR reaches the API with cookies;
- `SameSite=Lax` on every cookie;
- all state-changing routes are non-GET, and the backend **rejects any request
  whose `Content-Type` is not `application/json` (415, enforced in `ReadJSON`
  — §2.5, `webapp/2b-backend-transport.md`)**. This leg only holds if it is
  enforced: without the 415, a cross-site `<form enctype="text/plain">` posts
  without any preflight and can be shaped into valid JSON. With it, a
  cross-site sender must use JSON — which is not a "simple request", so it
  gets preflighted and blocked;
- checking `Origin` / `Sec-Fetch-Site` in middleware is a cheap additional
  leg worth adding;
- **therefore: never make a GET route state-changing.** `SameSite=Lax` still
  sends cookies on top-level cross-site GET navigations — a state-changing GET
  is your CSRF hole. Audit for it explicitly.
- `SameSite` is a cross-*site* control, not cross-origin: a sibling subdomain
  is same-site — never host untrusted content on one.
- Bearer-token clients (mobile, CLI) are outside CSRF entirely.

If any leg doesn't hold (cross-site deployment, form posts), add CSRF tokens.

**Rate limiting**: at minimum, targeted counters on abuse-prone auth paths —
login attempts per account, code attempts, email sends per hour, resend
cooldowns — atomic INCR+EXPIRE in Redis (Lua or pipeline). Keyed by
account/email (credential-stuffing resistance); volumetric per-IP limiting
belongs at the ingress/proxy layer. Return 429 with `retry_after`. A
break-glass local-admin door gets a per-address lockout.

**Panics**: `Recover` middleware logs the stack and returns a generic 500 —
the panic message never reaches the client. Debug detail in error responses
(cause, location) is gated on an explicit per-session debug flag for staff.

**`/metrics` and health endpoints** live on a separate listener/port with no
public route.

## 5.8 Frontend security

- **No tokens in JS-readable storage.** HttpOnly cookies only.
  `localStorage` is for theme and language.
- React's default escaping; **no `dangerouslySetInnerHTML`** (if you must
  render rich text, sanitize server-side and isolate the surface).
- `encodeURIComponent` every interpolated URL parameter.
- Client-side route guards are UX; the server is the authority (§3.3,
  `webapp/3-frontend.md`).
- For the API, keep JSON as JSON — HTML-escaping inside JSON is not an XSS
  control; the controls are `nosniff`, correct `Content-Type`, and CSP.
- Server-side field filtering (§2.5, `webapp/2b-backend-transport.md`) is the
  real "don't ship data the viewer shouldn't see" control for data-heavy UIs.
