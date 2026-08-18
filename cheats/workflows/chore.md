---
name: chore
description: "chore: housekeeping with no behavior change. Use for a prompt starting chore:, or a request to bump a dependency, adjust tooling, reformat, or tidy config."
---

# `chore:` — asap flow

<!-- F-060 -->

Deps, tooling, formatting, config. One pass, one person, minutes.

## 1. Confirm it is actually a chore

A chore changes no product behavior. If it does, it is a `feature:` or a
`refactor:`.

Two chores that are not chores:

- **A dependency bump with a breaking change** is a `migrate:`.
- **A config change that reaches production** is on the trigger list — it needs
  the devops gate. Editing a value that changes what runs is a deploy.

## 2. Do it

<!-- F-063 -->

Use the ecosystem's own command. **Never hand-edit a lock file or a manifest** —
they must stay in sync, and the divergence shows up on someone else's machine,
not yours.

<!-- F-064 -->

A formatting or lint chore never adds a suppression to make the build green. If
a rule now fires, fix the code or change the rule deliberately — not with a
per-line ignore.

<!-- F-017 -->

Finish it. A half-migrated formatter leaves the repo in a state where every
later diff is noise.

## 3. Verify

Build, lint, and the full suite — this is one of the few changes where the
_whole_ suite is the right check, because a chore touches everything and
protects nothing specific.

<!-- F-014 -->

Whatever you could not run is named.

## 4. Commit

<!-- F-060 --><!-- F-074 -->

`chore: <what>`, one line. If this repo opens PRs, a chore's PR carries a
two-paragraph description: the problem in one or two rows, the solution in one
or two rows.

<!-- F-062 -->

If the chore regenerated anything, the generated files travel in the same
commit.

## 5. Hand-back

<!-- F-013 -->

```
Changed:      files touched, one line each
Ran:          build / lint / full suite
Not verified: what you could not exercise, explicitly
Skipped:      follow-ups consciously left
```
