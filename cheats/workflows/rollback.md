---
name: rollback
description: "rollback: undo a shipped change. Use for a prompt starting rollback:, or a request to revert a deploy, go back to a previous version, or undo a release."
---

# `rollback:` — undo a shipped change

<!-- F-047 -->
**Rollback is reverting the commit that declared the new state.** Not a rebuild,
not a re-tag, not a hand-edit in a console.

This is a git operation. Treat it as one.

## 1. Decide: roll back or roll forward?

| Roll back                          | Roll forward                         |
| ---------------------------------- | ------------------------------------ |
| the previous version was healthy   | the previous version had its own bug |
| no migration contracted the schema | a contract step already ran          |
| the fix is not understood yet      | the fix is understood and one line   |

<!-- F-051 -->
**The migration question decides it.** If the release included a *contract* step
— a dropped column, a new NOT NULL — the old code cannot run against the current
schema, and rolling back the code alone will fail at boot or corrupt writes.
Then the answer is roll forward, and this is the moment to say so, not after the
revert.

## 2. Do it

<!-- F-045 -->
Revert the commit that changed the declared state. For an image-tag bump, that
is the bump commit; for a unit file or compose file, the commit that edited it.

<!-- F-048 -->
Do not fix it in a deployment UI. If a reconciler owns the environment, a
console edit is reverted by self-heal minutes later, without notice — you will
believe you mitigated an incident that is still running.

<!-- F-091 -->
Because artifacts are immutable, the previous version's bytes still exist. You
are pointing at them again, not rebuilding them.

## 3. Verify

<!-- F-046 -->
Same rule as shipping: verify the **artifact**, not the job.

- The revert commit landed on the branch the reconciler follows.
- The running version is the one you intended.
- The original symptom is gone. Watch error rate for several minutes.

A rollback that is not verified in production is a hypothesis, exactly like a
hotfix.

## 4. Close the loop

- The reverted change's branch or ticket is reopened, not silently dropped.
- Say **why** it was rolled back in one sentence, on the ticket. A revert with
  no reason gets re-merged by someone next week.
- <!-- F-007 -->If this class of failure has now happened twice, that is a
  convention nobody wrote down — record it per `practices/project-memory.md`.

## 5. Hand-back

<!-- F-013 -->
```
Changed:      the revert commit
Ran:          the deploy, and what the running system reported afterwards
Not verified: what you watched for and for how long
Follow-up:    what is now unshipped and who owns re-landing it
```
