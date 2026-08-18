---
title: Authorization
summary: Four layers from route gate to field filtering, roles parsed into a typed actor once at the boundary, and authorization filters kept in SQL.
keywords: [authorization, authz, route gate, 403, resource check, permission, field filtering, structured roles, actor, group hierarchy, SQL filter, approval policy]
related:
  - webapp/security-authentication.md
  - webapp/backend-transport.md
  - webapp/backend-entities.md
  - webapp/testing-http-e2e.md
---

# Authorization

## Layering authorization from coarse to fine

1. **Route-level role gate** (middleware): "may this class of user enter this
   door at all". Answers **403, never a redirect** — redirecting an
   authenticated-but-unauthorized user to login is an infinite loop with a
   friendly face. Stack it inside the auth middleware so a misordered route
   denies everyone — the safe direction for a wiring mistake.
2. **Resource-level decision in the service**, against ownership/delegation
   data, in **one place** (`mustSee` / `mustAdminister` helpers). The service
   is what fetches — a route added tomorrow that forgets to ask returns
   nothing, not everything. Router-level "GET is read, POST is write" is not
   sufficient when a POST can be semantically a read (see audited reads in
   `webapp/security-audit-logging.md`).
3. **Operation-level permission checks in entities** (`actor.CheckPerm(...)`),
   for rules that depend on both actor and target state
   (`webapp/backend-entities.md`).
4. **Field-level response filtering** by viewer role
   (`webapp/backend-transport.md`).

## Modeling roles and grants

- **Roles as structured strings** — whatever the scheme, parse them into a typed
  `Actor` **once at the transport boundary**; keep derived fields unexported
  ("a field anybody could set is a field somebody eventually sets from a
  request"). Where levels are ordered, the decision is an ordered comparison
  taking the maximum over matching grants.
- **Group hierarchies: expand the caller's side, not the grant's.** If a grant
  on a parent group must cover subgroups, expand the *user's* group list into
  its ancestor paths, then match with exact string equality — which stays
  indexable in SQL (`subject = any($1)`), where a prefix-match would be neither
  indexable nor honest.

## Keeping authorization filters in SQL

Authorization-relevant filters live in SQL, not Go: an expired grant must not
reach the decision at all — a filter the caller can forget is a filter somebody
eventually forgets.

## Versioning an approval policy

For an approval/change-management system: keep the policy **in a reviewed file
in version control, not a database table** the system itself can edit. Embed a
default so a failed config mount cannot silently degrade; refuse a policy that
renders any request kind unapprovable; when a template placeholder has nothing
to fill it, **drop the rule rather than widen it**.
