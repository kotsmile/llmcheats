---
title: Frontend security
summary: No tokens in JS-readable storage, React's default escaping with no dangerouslySetInnerHTML, and the server as the only authority on authorization.
keywords: [localStorage, HttpOnly, blast radius, XSS, dangerouslySetInnerHTML, encodeURIComponent, route guard, JSON escaping, nosniff, field filtering]
related:
  - webapp/security-http-hardening.md
  - webapp/frontend-auth.md
  - webapp/frontend-structure.md
  - webapp/backend-transport.md
---

# Frontend security

## Keeping tokens out of JS-readable storage

**No tokens in JS-readable storage.** HttpOnly cookies only. `localStorage` is
for theme and language.

The reason is blast radius: one injected script — your bug, a dependency's, an
extension's — reads `localStorage` and walks away with a session it can replay
off-box, while an HttpOnly cookie it cannot read only travels on requests the
browser was going to send anyway.

The trade is that CSRF becomes yours to handle, which is what the legs in
`webapp/security-http-hardening.md` are for; a frontend served from another
origin loses the same-origin leg (`SameSite` survives a sibling subdomain) and
a genuinely cross-*site* deployment owes a CSRF token instead.

## Avoiding XSS in the SPA

- React's default escaping; **no `dangerouslySetInnerHTML`** (if you must
  render rich text, sanitize server-side and isolate the surface).
- `encodeURIComponent` every interpolated URL parameter.
- Client-side route guards are UX; the server is the authority
  (`webapp/frontend-structure.md`).
- For the API, keep JSON as JSON — HTML-escaping inside JSON is not an XSS
  control; the controls are `nosniff`, correct `Content-Type`, and CSP.
- Server-side field filtering (`webapp/backend-transport.md`) is the real
  "do not ship data the viewer should not see" control for data-heavy UIs.
