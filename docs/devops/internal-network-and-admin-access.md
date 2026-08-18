---
title: Credential distribution and environment-scoped sessions
summary: Why you issue the credential and generate the config, why a config file holding a credential is itself a credential, and why a shell that changes the meaning of the next command must say so in the prompt.
theme: devops
keywords:
  [
    defense in depth,
    issued credential,
    generated config,
    credential file,
    fingerprint,
    migration,
    session scope,
    machine-global state,
    opt-in context,
    prompt marker,
  ]
related:
  - devops/rbac-role-grammar.md
  - devops/secrets-and-delegation.md
  - devops/ci-pipeline-composition.md
---

## A second gate under SSO

Single sign-on gating every request is necessary and not always sufficient. For a console that holds or grants the credentials everything else runs on, a **second, independent gate** — one that is not itself a login page — is worth the friction.

The argument is narrow and worth stating precisely: SSO failing open, or one stolen session, should not be the only thing between the internet and a credential store. Layers that fail differently are the point; two layers that fail the same way are one layer.

## Issue the credential, generate the config

Give an operator a **credential**, and generate the client configuration from it locally, every time. Do not distribute the config file.

The difference shows up when the config needs fixing. A distributed file has to be re-cut and re-installed by everyone holding a copy, and the people who miss it are invisible to you. A generated config picks up the fix on the next start.

Two consequences follow, and both have teeth:

- **That local config file is now a credential file.** Anything that dumps it for support or debugging must fingerprint the credential rather than print it — and "we'll remember not to paste it" is not a control.
- **A migration must never create a window with no copy.** Moving a credential from one file to another reads it back from the destination _before_ deleting the source. The tempting order — delete, then write — is one crash away from locking everyone out.

## Make a destructive context opt-in

Establishing an administrative environment can reasonably set an account, credentials and registry access. Attaching a context that a **destructive command would act on** should be a separate, explicit choice.

With no such context configured, there is no ambient answer to "where would this command land". That keeps it a conscious decision, and most administrative work needs no such context at all.

Prefer a token **scoped to the shell holding it** over a login command that writes machine-global configuration and moves a current context. Machine-global state outlives the terminal, and the next command inherits it without saying so.

## An environment that changes meaning must announce itself

A shell carrying elevated or production context should mark itself in the **prompt**, coloured, with the same fact exposed as an environment variable for scripts.

The principle: **when a tool changes the meaning of the next command you type, it must say so where you will read it.** That is the prompt — not a line printed at setup time, which has already scrolled away by the time it matters.

The failure this prevents is specific. A setup step that silently did not apply leaves a shell that looks exactly like one where it did, and the two differ only in what the next destructive command hits.

## Diagnose the tunnel, not the process

For any gated-network access: check that the **path works**, not that a client process is running. Those are different facts, and the process-only check is the one that produces confident wrong answers.
