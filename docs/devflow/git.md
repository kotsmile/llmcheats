---
title: Git — commits and pull requests
summary: One-line imperative commits carrying a ticket and scope, one logical change each, and pull requests whose four description blocks and approvals map to the flow's gates.
keywords: [commit message, ticket, scope, hotfix, chore, auto, one logical change, green before commit, secrets, squash merge, pull request, description, testing, rollback, review, approvals, force push, branch deletion]
related:
  - devflow/full-flow.md
  - devflow/asap-flow.md
  - devflow/scaling-down.md
  - devflow/roles.md
---

# Git — commits and pull requests

## Writing commit messages

**Format** — one line, ≤ 72 chars, imperative mood, no trailing period:

```
<TICKET>: <scope> what the change does
```

```
APP-42: api add order cancellation endpoint
APP-37: web fix token refresh race on tab wake
hotfix: api reject non-JSON content type on JSON routes
chore: bump Go to 1.26
```

- **`<TICKET>`** — the issue key when a tracker exists; it links the commit to
  the scope/design docs. No tracker → drop the prefix, keep the rest.
- **`<scope>`** — the component touched (`api`, `web`, `infra`, a service
  name). One word.
- **No-ticket prefixes**, only where they genuinely apply: `hotfix:`
  (fast-flow fix), `chore:` (deps, tooling, formatting), `auto:`
  (machine-written commits — deploy bumps, generated files — carrying a trailer
  that names who/what triggered them).

## Commit rules

1. **One logical change per commit.** A commit is revertable as a unit: code +
   its tests + the docs/generated files that change with it land together.
   Never mix a refactor with a behavior change.
2. **Single line only.** If the message needs a body to be understood, the
   commit is too big or the design doc is missing — fix that instead.
3. **Green before commit.** Build, lint, and the affected tests pass locally. A
   broken commit on a shared branch costs everyone's bisect.
4. **Never commit secrets** — no keys, tokens, dumps, `.env` with real values.
   A committed secret is rotated, not deleted (history keeps it).
5. **No AI attribution, no `Co-Authored-By` bots.** The author is whoever
   answers for the change.
6. **Generated files travel with their source** in the same commit (regenerated
   spec, rendered manifests) — CI verifies staleness.
7. **Main is protected**: changes arrive via reviewed merge requests; hotfixes
   may fast-track the review but never skip CI. Machine commits (`auto:`) are
   the only direct-to-main writes, and each carries its audit trailer.
8. **Commit ≠ deliver.** The agent/developer commits when the operator (or the
   project manager under delegated autonomy) asks or the flow's release stage
   requires it — never speculatively pushes.

## Writing pull requests

**Title** = the commit format: `<TICKET>: <scope> what the change delivers`.
Squash-merge inherits it, so the title is written as the future commit message.

**Description** — four short blocks, no template theater:

```
What:     one or two sentences — the change as shipped
Why:      link to the scope/design doc (or one sentence when none exists)
Testing:  what was run and where (suite, stand walk, repro test) —
          and what was NOT verified, stated explicitly
Rollback: how to undo (revert is the default answer; say so if it isn't —
          e.g. a migration that needs the contract step)
```

## Pull request rules

1. **One PR = one flow stage's output.** A feature lands as one reviewable PR
   (or a short stack); a hotfix is its own PR. Never bundle an unrelated "while
   I was here".
2. **Small enough to review honestly.** If the diff exceeds what a reviewer can
   actually read (~400 lines of non-generated change is the practical ceiling),
   split it — stacked PRs beat a rubber stamp.
3. **CI green is an entry condition for review**, not a post-review chore. Draft
   status while red or incomplete; mark ready only when it is reviewable.
4. **Gates map to approvals.** The flow's gate verdicts land as PR approvals:
   developer review always; security-auditor approval when the diff touches
   auth/input/SQL/secrets/PII; devops approval when it touches
   migrations/config/deploy. A BLOCKED verdict is a requested-changes review,
   not a comment.
5. **The author never merges over an unresolved finding.** Findings are fixed or
   explicitly risk-accepted by the gate owner in the PR thread — the thread is
   the audit trail.
6. **No self-merge**, with one exception: a hotfix under the fast flow may be
   merged by its author after CI + one post-factum review is requested — the
   review still happens, after the fire.
7. **Squash-merge by default** — main history is one commit per PR, revertable
   as a unit. Keep merge commits only for stacked PRs where intermediate history
   matters.
8. **Re-request review after force-push.** A force-push invalidates prior
   approvals; re-request instead of merging on a stale approval.
9. **Delete the branch on merge**; a PR open longer than a few days is re-scoped
   or closed — stale PRs rot into merge-conflict archaeology.
10. **Generated-file and docs updates ride the same PR** as their source (commit
    rule 6 — CI verifies staleness).
