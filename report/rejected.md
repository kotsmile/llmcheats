# rejected.md — findings that do not ship

Phase B output. A finding lands here when it is true of `$REFERENCE` and would
be false, harmful, or unverifiable somewhere else.

Two filters put things here:

- **Generalization test** — name two plausible repos where following the rule
  produces a *worse* outcome. If I can, it is not universal.
- **Falsifiability** — a shipped instruction must be a command that runs, a path
  that exists, or a check that can fail. Advice does not ship.

---

## R-01 · F-054 — CI job names must be prefixed with their project

- **Rule:** every job name carries a project prefix; an unprefixed duplicate
  silently overrides another project's job.
- **Why it does not ship:** it presupposes one flat pipeline assembled by
  recursive includes across a monorepo (`ci-pipeline-composition.md:14`). In a
  single-project repo there is no namespace to collide in, and the rule
  generates a naming ceremony that protects against nothing.
- **Worse in:** a single-service repo with six CI jobs; any repo on a CI system
  with real per-file job scoping (GitHub Actions workflows are already
  namespaced by file).
- **Kept as:** nothing. The general lesson — a merge that silently overrides
  rather than erroring is a failure mode with no error message — is real but
  belongs to no workflow I ship.

## R-02 · F-087 — Never run start commands for dev servers

- **Rule:** `commit-conventions.md:97` — "**Never run start commands** for dev
  servers — they are already running."
- **Why it does not ship:** the justification is a fact about the reference
  team's local setup, not about repos. Shipped blind, it stops an agent from
  running the one command that would verify its change in a repo where nothing
  is already running.
- **Worse in:** a fresh clone on CI; any repo where the agent is the only thing
  that would start the server.
- **Kept as:** a question the setup skill asks the target repo rather than a
  rule it asserts — if a dev-server command exists, `stack.md` records whether it
  is operator-managed. The underlying principle (do not start a long-running
  process an operator may already be running) is real; the flat prohibition is
  not portable.

## R-03 · F-041 (roster half) — The eleven-agent role roster

- **Rule:** `roles.md:19-31` maps eleven roles to eleven named agent
  definitions (`project-manager`, `architecture-designer`, `golang-developer`,
  …).
- **Why it does not ship:** two reasons, and the second is the disqualifying
  one. It is a Claude-Code-only mechanism with no Codex equivalent, so it would
  be a limb one of the two target agents cannot use. And it is the roster of a
  specific team's specialization, not a property of repos — a Rust shop gets
  `golang-developer` for nothing.
- **Also:** the user's payload decision put agents out of scope for this build.
- **Kept as:** the universal half — gates are properties of the change, not of
  the headcount, and they survive one person holding several hats
  (`roles.md:15`, `scaling-down.md:17`). That ships in `practices/flows.md`.

## R-04 · F-057 (console half) — A secrets console's internal model

- **Rule:** `secrets-and-delegation.md` — the internal design of a specific
  secrets console and its delivery path into a cluster.
- **Why it does not ship:** it describes one organization's internal service,
  in enough detail to reconstruct it. No target repo has it, and the detail is
  not ours to publish.
- **Kept as:** the universals extracted from it — every read of a secret is
  audited, a token inherits the identity of whoever minted it, and the
  two-writer prune lesson: whichever writer holds the "delete what I don't know
  about" flag will eventually delete the other's work. The last ships as a
  constraint on agents: never hold the prune flag.

## R-05 · Everything under `best/backend/llm-*` — the LLM subsystem's internals

- **Rule:** four files on classifier-not-orchestrator routing, provider factory
  registries, ADD-only typed-fact memory with temporal rotation, and the
  trigger/step pipeline engine.
- **Why it does not ship as a rule:** it is one product's architecture. A repo
  with LLM features does not thereby need a typed-fact store with supersede
  semantics.
- **Kept as:** routing only. The files install with the rest of the corpus and
  the routing table points at them when the target repo has LLM features
  *and* the task touches them. Reference material behind a guard is not the same
  as a shipped rule — this is the whole point of the payload decision.

## R-06 · The mobile corpus — `best/frontend/mobile-*`

- **Rule:** three files on React Native stack choices, styling traps that
  compile and still fail, and home-screen widget verification gates.
- **Why it does not ship as a rule:** assumes React Native, a managed SDK, and a
  widget extension. Useless-to-harmful anywhere else.
- **Kept as:** routing behind a `react-native` detection guard. The
  widget-verification file carries one genuinely portable idea — three
  verification gates each blind to the next one's failure
  (`mobile-widget-verification.md:21`) — but it is inseparable from its
  substrate, so it stays reference rather than rule.

## R-07 · F-076 — Extract a function only when it has more than one caller

- **Status:** **shipped, but demoted from constraint to pattern.**
- **Why it nearly landed here:** it fails the generalization test twice. A
  codebase whose house style is named single-use helpers for readability gets
  worse. A codebase that extracts single-use functions specifically to make them
  unit-testable gets worse.
- **Resolution:** it ships in `practices/code-style.md` labelled a **pattern**
  under F-038 — advisory, yields to local convention — not as a constraint. The
  reference states it as a review rule, which earns it a place; it does not earn
  authority over a repo that already decided otherwise.

## R-08 · F-096 (memo half) — No manual `useMemo`/`useCallback`/`memo`

- **Status:** **shipped with a version guard, not a language guard.**
- **Why it nearly landed here:** the rule is not merely inapplicable outside
  React — it is *actively wrong* on React ≤18 without the compiler, where manual
  memoization is the supported mechanism. A `stack-specific` guard reading
  "TypeScript + React" would ship a correctness bug.
- **Resolution:** guarded on React 19 **and** React Compiler being enabled, both
  checked in the target repo. This finding is the reason the guard vocabulary
  carries a version dimension at all.

## R-09 · Advice that failed the falsifiability filter

Cut wholesale, with no F-number, because they are not checkable:

| Text | Source | Why cut |
|---|---|---|
| "The architecture is deliberately boring." | `system-shape.md:27` | A stance, not a check. |
| "SOLID without over-engineering." | `typescript-react-conventions.md:30` | Cannot fail. |
| "Choose by team size and operational maturity, not fashion." | `infrastructure.md:17` | No observable trigger. |
| "Consider `-race` in CI when the suite affords it." | `testing-ci.md:19` | "Affords it" is unfalsifiable; the local `-race` half ships because it is a command. |
| "Keep docs next to the code." | `release-artifacts.md:31` | Ships only in its checkable form — a doc path inside the repo, not a wiki URL. |

## R-10 · The prompt's own `<!-- llmcheats:keep -->` marker

- **Not a finding — a specified behaviour I am not implementing.**
- **Why:** `project-memory.md:104-110` specifies the inverse convention
  (`llmcheats:begin`/`llmcheats:end`, memory written *outside*, installer
  preserves everything outside). Shipping both would give a target repo two
  marker systems with opposite defaults for an unmarked line.
- **Consequence if this call is wrong:** re-running the setup skill would
  preserve too much rather than too little — it would leave a stale hand-written
  section standing where the prompt intended a rewrite. That is the safer
  failure direction, which is part of why I chose it.
- **Reversal cost:** one constant in the setup skill and one line in the
  template.

---

## Tally

| Disposition | Count |
|---|---|
| Rejected outright | 4 (R-01, R-02, R-05 as rule, R-06 as rule) |
| Split — universal half kept | 2 (R-03, R-04) |
| Shipped, demoted or guarded | 2 (R-07, R-08) |
| Cut as unfalsifiable | 5 lines (R-09) |
| Specified-but-not-built | 1 (R-10) |

Every `project-idiosyncratic` finding in `findings.md` appears above. No finding
was dropped silently.
