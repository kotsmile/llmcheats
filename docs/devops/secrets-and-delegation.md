---
title: Secrets — machine credentials and the two-writer trap
summary: Why a machine token should carry no permissions of its own, why an expiry on a reconcile loop is a scheduled outage, and the prune mode that deletes the other writer's work.
theme: devops
keywords:
  [
    secrets,
    machine credential,
    API token,
    subject,
    hash,
    revocation,
    audited read,
    reconcile loop,
    expiry,
    prune,
    two-writer,
    secret map,
  ]
related:
  - devops/rbac-role-grammar.md
  - devops/service-config-in-charts.md
  - backend/configuration-loading.md
---

## Metadata in the console, payloads in the store

A secrets console is best built as an **aggregator**: the payload stays in the backing secret manager, and the console's own database holds only who may see what, and an audit trail.

The trail should record **reads**, not just writes. A read of a secret is the event that matters — a write is recoverable, a read is not — and read logging is the thing most often left out because nothing breaks without it.

## A machine token should carry no permissions of its own

Store the **subject** and a hash of the secret half. Do not store the roles.

Every request then re-asks the identity provider who that subject currently is and what it may do, behind a short cache. Two properties follow, and both are the point:

- **Disabling the account, or removing a role, cuts every token it issued** within the cache window. A session-only design gets this for free; a token design only gets it by refusing to denormalise permissions into the token row.
- **A token inherits the identity of whoever minted it.** Mint machine credentials while signed in as the machine's own account. A token minted by a human administrator is a human administrator, and it will be used by a script that nobody thinks of as privileged.

Show the plaintext **once**, in the response that creates it, and store only the hash. A lost credential is replaced, never recovered.

The general shape worth copying: replacing a credential recipe that involved pasting an account password into a command line with a **button that mints and revokes** removes a whole class of credential sprawl. If issuing a machine credential is awkward, people will share a human one.

## Do not expire what a reconcile loop presents

**An expiry on the credential a reconcile loop presents is an outage scheduled for a day nobody picked.**

The rotation instinct is right for credentials a human holds and wrong for the ones an automated loop presents unattended. If the loop's credential must rotate, the rotation has to be automated end to end — otherwise the expiry date is just a deferred incident with no owner.

## Keep secrets out of charts

One flat secret map per application and environment, reaching pods through a secrets operator. **Nothing secret is ever written into a chart's values** — the chart carries a placeholder, the map carries the value.

The reason is reviewability as much as secrecy: a chart is read, diffed and copied far more often than a secret store is.

## The prune trap

This one generalises well beyond secrets.

A declarative sync tool that compares a store against a local file, with a **prune** mode, deletes whatever the file does not declare. Anything created through another writer — a browser UI, a second tool, a human — is by definition not in that file.

**This is the general shape of a two-writer system: whichever writer holds the "delete what I don't know about" flag will eventually delete the other's work.**

Mitigations, in order of preference: do not run prune at all; or make every object the file's to declare, so there is only one writer; or read the removal list before confirming, every time. The plain push never deletes — only prune does.
