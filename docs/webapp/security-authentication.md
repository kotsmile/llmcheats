---
title: Authentication
summary: First-party JWT for product apps, backend-terminated OIDC with an encrypted session cookie for staff consoles, and hashed random secrets for machine tokens.
keywords: [JWT, access token, refresh token, HttpOnly cookie, Bearer, JTI, OIDC, Keycloak, AEAD, cookie version, JWKS, azp, state, machine token, SHA-256, constant time, fail closed]
related:
  - webapp/security-authorization.md
  - webapp/frontend-auth.md
  - webapp/backend-transport.md
  - webapp/security-http-hardening.md
---

# Authentication

## Issuing first-party JWTs

For product apps serving an end-user browser and mobile clients:

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

## Terminating OIDC in the backend

For staff/console apps the backend terminates OIDC against the IdP (e.g.
Keycloak) and issues its own session cookie. Hard-won rules:

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
  hangup does not fail the coalesced waiters).
- **Token verification**: JWKS via OIDC discovery; check signature, issuer,
  expiry. If your IdP does not reliably populate `aud` for API access tokens,
  verify the authorized-party claim (`azp`) against an explicit client
  allowlist instead — the check moves, it must not disappear. Strip empty
  strings from the allowlist at construction so an unset env var cannot become
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

## Issuing machine tokens

For service-to-service and CLI access. Format `prefix_<public-id>_<secret>`:
8-byte id + 32-byte `crypto/rand` secret.

Store **plain SHA-256** of the secret — a slow KDF defends small-keyspace
passwords; a 256-bit random secret has nothing to iterate against. What
matters: plaintext never stored, comparison constant-time
(`subtle.ConstantTimeCompare`).

Check order is cheapest-first and fail-early: shape → stored hash → expiry →
*only then* any upstream identity resolution, so unauthenticated garbage never
reaches your IdP.
