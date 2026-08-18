---
title: Secrets
summary: Secrets travel secret manager to env var to a ${VAR} placeholder, are never logged, are redacted out of responses, and encrypt sensitive data at rest with AES-GCM.
keywords: [secrets, secret manager, env var, placeholder, redaction middleware, no-store, encryption at rest, AES-256-GCM, nonce, key rotation, key length]
related:
  - webapp/backend-config-lifecycle.md
  - webapp/infrastructure.md
  - webapp/security-frontend.md
  - webapp/security-audit-logging.md
---

# Secrets

## Delivering secrets to the process

**Delivery chain**: secret manager → deployment secret → env var → `${VAR}` in
the config file. The app never fetches secrets itself and never reads env vars
directly (`webapp/backend-config-lifecycle.md`). The deployment half of this
chain is in `webapp/infrastructure.md`.

## Keeping secrets out of logs and responses

- **Never log the config.**
- Expose the list of secret *values* to a response-redaction middleware that
  replaces any occurrence in a JSON response with `[REDACTED]` — with a
  minimum-length floor (~12 chars) so a dev default like `postgres` does not
  shred responses. Skip it for streaming routes.
- Secret-bearing responses set `Cache-Control: no-store, max-age=0`.
- On the client: revealed secret values live in component state and die with
  it — never in the query cache, never in any storage
  (`webapp/frontend-data.md`).

## Encrypting sensitive data at rest

For sensitive user content (private chat, health data): AES-256-GCM, random
nonce per message stored beside the ciphertext, AEAD tag as tamper detection.
One shared cipher instance for the domain so key rotation touches one place.
Validate key length at startup (16/24/32 bytes), not first use.
