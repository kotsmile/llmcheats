# Git

## Commit messages

<!-- F-059 -->

**One line.** Imperative, ≤72 characters, no trailing period, no body.

```
<TICKET>: <scope> what the change does
```

If the message needs a body to be understood, the commit is too big or the
design doc is missing. Fix that instead of writing the body.

<!-- F-060 -->

Three no-ticket prefixes, and only where they genuinely apply:

| Prefix    | When                                                         |
| --------- | ------------------------------------------------------------ |
| `hotfix:` | urgent production fix                                        |
| `chore:`  | deps, tooling, formatting                                    |
| `auto:`   | machine-written, carrying a trailer naming what triggered it |

`stack.md` records whether this repo uses a tracker key and what its scope
vocabulary is. No tracker → drop the prefix, keep the rest.

## Commit rules

<!-- F-042 -->

1. **One logical change per commit**, revertable as a unit: code, its tests, and
   the generated files that change with it land together. **Never mix a refactor
   with a behavior change.**
2. <!-- F-065 -->**Green before commit.** Build, lint and the affected tests pass
   locally. A broken commit on a shared branch costs everyone's bisect.
3. <!-- F-067 -->**Never commit secrets** — no keys, tokens, dumps, `.env` with
   real values. A committed secret is **rotated, not deleted**; history keeps it.
4. <!-- F-061 -->**No AI attribution, no `Co-Authored-By` bots.** The author is
   whoever answers for the change.
5. <!-- F-062 -->**Generated files travel with their source** in the same commit.
   CI verifies staleness.
6. <!-- F-066 -->**Commit ≠ deliver.** Commit when the operator asks or the
   release stage requires it. Never speculatively push.

## Before opening a pull request

<!-- F-074 -->

**Ask: ticket or chore? Never guess.** The answer sets three things:

| Answer       | Branch                 | Title                | Description                       |
| ------------ | ---------------------- | -------------------- | --------------------------------- |
| a ticket key | `<KEY>-<n>-short-name` | `<KEY>-<n>: <title>` | none                              |
| chore        | `chore-short-name`     | `chore: <title>`     | two paragraphs: problem, solution |

## Pull requests

<!-- F-068 -->

Four blocks, no template theater:

```
What:     one or two sentences — the change as shipped
Why:      link to the scope or design doc, or one sentence when none exists
Testing:  what was run and where — and what was NOT verified, explicitly
Rollback: how to undo (revert is the default; say so when it isn't)
```

<!-- F-069 -->

- **Small enough to review honestly.** ~400 lines of non-generated change is the
  practical ceiling. Past it, split — stacked PRs beat a rubber stamp.
- <!-- F-070 -->**CI green is an entry condition for review**, not a post-review
  chore. Draft while red.
- <!-- F-071 -->**Gate verdicts land as approvals.** A BLOCKED verdict is a
  requested-changes review, not a comment. The author never merges over an
  unresolved finding.
- <!-- F-072 -->**No self-merge**, with one exception: a hotfix may be merged by
  its author after CI, with a post-factum review requested. The review still
  happens, after the fire.
- <!-- F-073 -->**Squash-merge by default** — one commit per PR on main,
  revertable as a unit. **Re-request review after a force-push**; it invalidates
  prior approvals.
- Delete the branch on merge.
