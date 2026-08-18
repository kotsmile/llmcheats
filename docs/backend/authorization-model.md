---
title: Guards versus permissions — the two authorization layers
summary: Route-level guards and operation-level permissions are separate mechanisms; which one to extend and where each lives.
theme: backend
keywords: [guard, GuardMap, GuardFunc, permission, Perm, Check, role, route access, IDOR, actor, role map, adding a role]
related:
  - backend/http-endpoints-and-middleware.md
  - backend/layered-architecture.md
  - devops/rbac-role-grammar.md
---

## Two distinct layers

| Layer          | Question it answers                    | Where it lives                 | How it is applied                                           |
| -------------- | -------------------------------------- | ------------------------------ | ----------------------------------------------------------- |
| **Guard**      | Can role X hit endpoint Y?             | the domain's transport package | `Auth(handler, SupportGuard)`                               |
| **Permission** | Can user X perform action Z on user W? | the domain's entity package    | `actor.CheckPerm(PermUserActivate)` inside an entity method |

They are deliberately separate. **Do not duplicate permission logic in the transport layer.**

## Guards

Declared in the transport layer — never in entity:

- `NewGuardMap(...)` — access by base role.
- `NewGuardFunc(...)` — feature flags, staff checks, anything computed.

A role carrying a sub-type (e.g. a specialist with a speciality) is matched by its base role, so guards do not enumerate sub-types.

## Permissions

A `Perm` type with a `Check(role) error` method backed by an inline `{role -> {perm: true}}` map, called at the start of the entity method that protects the operation.

The map is deliberately asymmetric — a manager role may reset a password and assign staff without being able to activate an account, which only an admin may do.

## Adding a privilege

- **A new endpoint for an entire role** → a Guard.
- **An operation on an entity** → a `Perm` const, an entry in the role map inside `Check`, and a `CheckPerm` call at the top of the protecting entity method.

A role added to the map with an empty `{}` still needs the entry, or the lookup falls on a zero-map.

Add a table-test case for each relevant role, positive and negative.

## Adding a role

1. Declare the const and the sentinel value, and add it to the valid-roles map (and the staff-roles map if applicable).
2. If the role has a crew key, extend both directions of the key mapping — otherwise assignment rejects it with a mismatch error.
3. Add an entry to the role map inside `Check`.
4. Add its Guard.
5. A new enum value in the role column is a **column contract** — discuss before writing the migration.

Do not remove a base-role sentinel even when no user holds it directly: it is the key the guard and permission maps are indexed by.

## Ownership checks inside tools and detail endpoints

Any endpoint or model tool that renders one record by id must scope the lookup to the caller's own records. This is enforced in the provider that fetches the record, not in the caller — an IDOR guard placed at the callsite is one forgotten callsite away from a leak.
