# Development Flow — asap flow (small work, one pass)

## 10. Asap flow — one person, now

The third flow, and the smallest. §3 (`devflow/2-full-flow.md`) designs before
it builds; §5 (`devflow/3-fast-flow.md`) fixes an agreed-broken behavior; the
**asap flow delivers a small piece of work in a single pass**, with one person
— or one agent, `asap` — holding every hat.

Target duration: **minutes**. Work that cannot plausibly finish in one sitting
is not asap work; it is a feature wearing a hurry.

This flow is a deliberate trade, and it is written down so the trade is
visible: you give up the design artifact, the independent product review, and
the separate security and devops gates. You do **not** give up §1's
(`devflow/1-principles-roles.md`) never-skip list, and you do not give up
knowing what you did not verify.

### 10.1 When it applies

- A small feature or tweak inside patterns that already exist in the codebase.
- Glue: wiring an existing endpoint to an existing screen, a config knob, a
  script, a one-off migration of *local* data.
- Spikes, prototypes, internal tooling, developer experience.
- Anything where a wrong answer is cheap and instantly visible.

### 10.2 When it does not — hand to the full or fast flow instead

- Auth, sessions, tokens, crypto, secrets, payments, PII.
- Schema migrations, data backfills, anything irreversible on real data.
- Production deploys, infra topology, anything needing a rollback story.
- Public product surface, or any task where *what correct means* is still open
  — that is a product decision, and it is not the implementer's to make.
- Anything whose diff outgrows what a reviewer reads in one sitting (§8,
  `devflow/5-git.md`).

The trigger list is checked **at intake and again mid-task**: an asap task that
grows into one of these stops and is re-flowed. That is a normal outcome, not
a failure.

### 10.3 A1. Intake — one sentence

State the task and what "done" looks like, in one sentence, and start. No scope
doc, no acceptance-criteria table, no plan-approval gate: if the operator is
watching, the sentence *is* the plan; if they are away, it is still a
statement, not a request — the escalation triggers in §10.2 are what protects
them, not an approval round-trip.

### 10.4 A2. Build

- Read the surrounding code first. Extend the pattern that is already there;
  consistency with neighbours beats the pattern you would have chosen.
- The smallest change that fully does the job. No opportunistic refactor.
- **Finish it.** No TODO stubs, no half-wired path. Work delivered at 80% is
  work the operator now has to finish, which is the opposite of fast.

### 10.5 A3. Verify

- Build, lint, and the tests around the change — run, not assumed.
- Fixing a defect under this flow still means the **reproduction test is
  written first** and fails before the fix (§5's F3 rule in
  `devflow/3-fast-flow.md`; it does not collapse).
- New behavior gets a test when the behavior is worth protecting. Skip the test
  for a spike or a throwaway script, and *say* you skipped it.
- Whatever you could not run is named. An unrun path is never reported as
  passing.

### 10.6 A4. Hand-back

Four lines, no ceremony:

```
Changed:      files touched, one line each
Ran:          build / lint / tests / manual check, and what they said
Not verified: what you could not exercise, explicitly
Skipped:      follow-ups you consciously left (the refactor, the doc, the test)
```

### 10.7 The floor

Speed buys the ceremony, never these:

- Secrets are never hardcoded, logged, or committed.
- SQL is parameterized; client input is validated at the boundary.
- No auth or authz check is weakened, bypassed, or temporarily disabled.
- No test is deleted or skipped, and no `//nolint` / `# noqa` /
  `eslint-disable` is added, to make a build green.
- Errors are handled or returned, never swallowed.
- Nothing destructive touches shared or production state without an explicit
  go-ahead: no drop, truncate, mass delete, force-push, or deploy.

A task that cannot be done without breaking one of these is an escalation, not
a judgment call. This is the §1 never-skip list of
`devflow/1-principles-roles.md` at asap scale — the ceremony scales down, the
floor does not.

### 10.8 Git

`hotfix:`-style single-line commits per §8 (`devflow/5-git.md`), one logical
change, green before commit. An asap change still arrives via a PR when the
repo requires one; what it may skip is the *gate approvals* (§8 rule 4,
`devflow/5-git.md`) that its scope does not trigger — and if it triggers them,
it was never an asap task.
