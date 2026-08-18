---
title: Model routing and the tool registry
summary: Why the entry point is a classifier rather than an orchestrator, how a role's tool catalogue is derived, and the one-file-per-tool registration pattern.
theme: backend
keywords: [router, classifier, intent, orchestrator, agent role, tool registry, toolSpec, dispatch, parse, execute, tool choice, forced tool, anti-trigger, JIT tool, cache prefix]
related:
  - backend/llm-provider-abstraction.md
  - backend/llm-memory-and-pipelines.md
  - backend/llm-safety-and-tracing.md
  - backend/websocket-hub.md
---

## Router, not orchestrator

The entry point is a **classifier** running on the cheap model. It returns only `{intent, confidence}`.

The selected agent role then receives the user's **original text**, a template prompt and static context. There is no query enrichment, no handoff, no multi-agent synthesis phase.

One role acts as the general-purpose fallback, activated only on a general intent or a classifier error. It is **not** a coordinator: it has no consult-another-role tool, no synthesis step and no routing authority. The majority of traffic never reaches it.

A common misreading is the word "coordinate" appearing inside that role's prompt. Introducing a real orchestrator is an explicit architectural transition — discuss before implementing it.

## Roles and their tool catalogues

A role's tool catalogue is assembled by a forward-pass filter over the master tool list.

**The role lives in the tool's spec, never in the file layout**, and master-list order is load-bearing: it is the prompt cache prefix. Read the current catalogue from the master list function, not from directory contents.

Some roles are virtual — used as an author attribution on stored facts, never displayed and holding no identity of their own.

## Load-on-demand read tools

Data is fetched by tool call instead of being preloaded into every prompt. The pattern replaced three separate preloaded blocks and is worth understanding before adding a fourth:

- A **list tool** reads a collection over an arbitrary range and returns a compact overview — one line per record plus a per-kind key metric — with an id prefix on each line for drill-down.
- A **detail tool** renders ONE record in full, scoped to the caller's own records by an ownership guard in the provider.
- A **reference tool** returns codes, ranges and aliases on demand, replacing a static catalogue that used to be baked into a prompt.

Preloading loses on two counts: it burns context on every turn, and a fixed backward-looking window silently hides anything outside it. The list tool that replaced one such block exists precisely because the old window could not see forward.

Visibility is per role and narrower than the writer set: one role sees only the record kind it needs to answer questions about, so it can stay a responder rather than becoming a planner. **Write access is gated by which edit tools a role has, not by what it can see.**

## Where a tool lives

**Entirely in one domain file** in the service package. That file holds the tool spec — name, roles, description, schema, processing strings, dispatch — **and** its input type, parser and executor.

There is no manual name list, no processing map and no dispatch switch; all derive from the master list. Registry-bijection and processing-completeness tests turn a forgotten piece into a test failure instead of a silent desync.

```go
var myTool = toolSpec{
	Name:         myToolToolName,
	Roles:        []AIRole{RoleNutritionist},   // or the all-roles set
	Description:  "...trigger + anti-trigger...",
	Schema:       json.RawMessage(`{...}`),
	ProcessingEn: "...", ProcessingRu: "...",
	Dispatch:     dispatchMyTool,
}

type myToolInput struct{ ... }

func parseMyTool(tu ToolUseBlock) (*myToolInput, error) { ... }

func dispatchMyTool(s *Service, ctx context.Context, dctx *dispatchCtx, tu ToolUseBlock) {
	in, err := parseMyTool(tu)
	if err != nil { dctx.results[tu.ID] = "Error: " + err.Error(); return }
	dctx.results[tu.ID] = s.executeMyTool(ctx, dctx.userID, in)
}
```

## Registration checklist

1. **Domain file** — everything above, in one place.
2. **Registry** — add the name const and insert the spec into the master list **at the right position**, inside the role block. Order is the cache prefix.
3. **Prompt** — state when to invoke it (trigger) **and when not to** (anti-trigger). The anti-trigger is what prevents over-triggering, which is the most common regression.
4. **Tests** — parser and executor. The golden snapshot of the tool set will fail because the set changed; re-baseline deliberately.
5. **Multi-role** — list several roles in the spec; the filter handles it. No duplication.
6. **Forced single tool** — for a pipeline call that must invoke one specific tool, expose a definition getter for it.
7. **Client rendering** — if the tool emits an attachment, handle it in the client's stream store.

## Validation rules

- **Never trust tool input.** Validate enums, bounds and format in the parser; an invalid input becomes an error string in the tool result.
- **On failure the executor must return an error string.** Otherwise the outcome classifier reads success and the model confirms work that did not happen.
- The model must never pass raw user text into a structured field — it must extract a value.

## Shared infra rule

Helpers used by **both** a chat tool and a background pipeline stay in the shared composer files — they are infra, not a tool. Only the tool's own parse and execute live in the domain file.

## Streaming

Streaming is server-sent events into a delta channel. Always wrap stream errors in a context-cancellation check. Wire events are declared as typed constants, each carrying its contract in a doc comment, and are broadcast through the hub's raw path.

## After any change

Run the evaluation suite. Prompt, tool and routing changes all require it; a tool that over-triggers passes unit tests and fails evaluation.
