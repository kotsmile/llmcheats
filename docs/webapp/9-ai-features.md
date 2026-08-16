# 9. AI features

LLM functionality is a feature like any other: it lives inside the same
layered architecture, passes the same gates, and its inputs are as untrusted
as any other user input. What changes is where the risks concentrate.

**Where things live:**

- **Prompts are code.** System prompts, persona definitions, and routing
  instructions live in the AI domain's `service/` layer (e.g. `prompt.go` or
  a `prompt/` subpackage) — versioned, reviewed, diffable. Never in a
  database or an admin panel, where they drift unreviewed. Keep the static
  part first and stable: provider prompt caching keys on the prefix, and
  reordering it silently destroys the hit rate.
- **The LLM provider is a port**: declared as an interface in `service/`,
  implemented in `infra/` (one package per provider). Business logic is then
  testable with hand-written fakes (§4.3) — no network, deterministic
  responses, scriptable tool calls.
- **Tool/function-call executors are a transport layer for an untrusted
  client.** The model is a client: every argument is validated server-side
  (bounds, enums, authz for the acting user) exactly like a public endpoint
  (§5.3), and a tool call must never authorize more than the user could do
  directly. Retrieved or user-supplied content entering the context is data,
  not instructions — delimit it explicitly.
- **Conversation data is sensitive by default**: encrypted at rest (§5.5),
  access audited (§5.6), never plaintext in logs or traces.

**Deadlines and side effects:** a synchronous LLM round gets a justified
carve-out in the timeout budget (§6.2); streaming responses run outside the
timeout group. The trailing database write after a slow LLM call runs on a
context that survives cancellation (`context.WithoutCancel` + its own short
timeout, §6.3) — otherwise the write fails on the already-cancelled request
context and the client retries the whole generation into duplicates.

**Safety is layered**: deterministic pre-LLM input gates (pattern or
classifier checks that cannot be talked out of), prompt-level constraints,
and output-side checks where stakes demand them. Never rely on the prompt
alone for a hard constraint.

**Evaluation is two-level** (the AI layer's regression suite):

- **Level 1 — deterministic unit tests**, blocking in CI: safety filters,
  tool-argument parsers, prompt assembly (right blocks, right order), context
  budgeting.
- **Level 2 — a scenario corpus** (YAML, versioned next to the code) judged
  against a rubric per dimension — routing, persona boundaries, safety,
  tool-use triggers. Add a scenario for every production incident before
  fixing it. See the `ai-engineer` agent for the full methodology.

**Cost is an engineering budget**: tier models by task (cheap models for
classification and extraction, strong models for generation and judgment),
measure tokens/cost/latency per conversation with an LLM tracing tool, and
treat every token of system prompt as multiplied by daily request volume.
