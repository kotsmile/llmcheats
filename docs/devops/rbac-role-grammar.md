---
title: Access control — design principles
summary: Why the plane that changes access must stay out of the request path of the plane that enforces it, and the naming, approval and rename rules that keep a role scheme honest.
theme: devops
keywords:
  [
    RBAC,
    access levels,
    management plane,
    enforcement plane,
    role naming,
    renames,
    session lifetime,
    approvals,
    provisioner,
    directory lookup,
  ]
related:
  - devops/secrets-and-delegation.md
  - backend/authorization-model.md
---

## Management and enforcement are different planes

The service that **changes** access and the service that **enforces** it should not be the same, and the enforcing side should not call the changing side at request time.

An identity provider issues tokens; a service learns who the caller is and what they hold **from the token**. An access-management service takes requests, applies an approval policy, and writes the declarations — then gets out of the way.

**The test: the access service being down must cost the ability to _change_ access, not the ability to _use_ it.** Any design where a request-path service asks the management plane "may this caller do this" fails it.

A corollary that is easy to get wrong: user and group autosuggest belongs in a **shared directory lookup** reaching the identity provider, not in an endpoint on the access service. Every console then improves at once, and no console acquires a request-time dependency on the management plane.

## Access levels are worth making disjoint

The intuitive design nests levels — write implies read, manage implies write. The alternative is to make them **disjoint**, so someone meant to do two things holds two grants.

Disjoint costs more grants and buys one thing: a role means exactly what it says. A nested scheme quietly hands out reads with every write, and the blast radius of a grant stops being legible from its name.

If levels are ordered anywhere, keep it to the **catalogue** — where a search reads as a floor and listing a broader level alongside a narrower one is a convenience. Ordering in a *listing* is fine. Ordering in an *enforcement decision* is the thing being avoided.

A useful separate axis: an approval-only level that opens nothing in the system it names. Being able to approve a grant and being able to use it are different powers, and collapsing them means whoever administers the permission system can grant themselves anything.

## One spelling per role

A rename must delete the old name **and update every reader in the same change**, so a service accepts exactly one canonical string. Two accepted spellings is two sources of truth that will diverge.

Sessions minted before the change keep the old strings until they expire. **Plan a rename around session lifetime, not around deploy time** — the window where both must work is set by how long a session lives, not by how long the rollout takes.

## Scope that a file expresses better stays in the file

Where a workflow already declares its permitted users beside its definition, the role that gates it stays coarse and the declaration carries the scope.

Adding a fine-grained per-object role for something a code review already answers gives you two places to look and two places to disagree.

## Filing a request is not deciding it

Keep **requesting** open — a low-privilege role that lets anybody request anything about anybody is correct, because what a request produces is somebody else's decision. Gate the **approval**, not the filing.

Approver sets are better **additive** than exclusive: several roles can approve a given request, and each covers a scope. The failure mode of an exclusive design is a single approver who is on holiday.

On self-approval: a two-person rule sounds obviously right and is often theatre. If an approver could already grant the same thing to anyone else, requiring a colleague to type it adds a step and no control. Decide it deliberately rather than inheriting it.

## Adding a system to the scheme

Have systems implement a small **provisioner** interface — "make this role exist in my world" — so granting a role can create whatever the target system needs. A system that reads its role straight out of the token implements nothing.
