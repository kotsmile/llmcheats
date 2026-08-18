---
title: Long-term fact memory and the background pipeline engine
summary: The ADD-only typed-fact store with temporal rotation, and the trigger/step engine that runs all queue-backed and periodic work.
theme: backend
keywords: [memory, typed fact, ADD-only, supersede, archive, TTL, review due, audit row, role ownership, pipeline engine, cron trigger, executor, SKIP LOCKED, step, StepResult, conversation summary]
related:
  - backend/llm-routing-and-tools.md
  - backend/llm-safety-and-tracing.md
  - backend/database-and-migrations.md
---

## Two kinds of memory — do not conflate them

| Kind | Storage | Lifetime |
| --- | --- | --- |
| **Long-term facts** | A typed-fact table | Across conversations, with explicit rotation |
| **Conversation memory** | Recent turns plus a rolling summary | The current dialogue only |

Conversation memory keeps the last ~20 turns encrypted at rest; past a message threshold a summarisation call on the cheap model condenses the history into a summary column.

## The fact store

The earlier design — a single plain-text blob rewritten wholesale by a tool — was **removed completely**, columns included. Its failure mode was that every write was a full rewrite, so one bad extraction destroyed everything the model had learned.

The replacement is a table of **typed facts** with two tools: add a fact, and archive a fact.

### Core rules

- All writes go through the store's add method.
- **ADD-only.** Never update an existing row. Supersede instead: a new row pointing at the old one, the old row moving to archived and pointing back. The "superseded" state derives from the back-pointer, so it cannot disagree with the row.
- **Role ownership is enforced server-side** by a per-type writer check, evaluated **before** the write. The executor rejects a violation with an error in the tool result — it is not the prompt's job to enforce this.
- **Every mutation writes an audit row in the same transaction.**
- **Cross-domain visibility**: every agent role *sees* every fact on render. Filtering happens only on **write**.
- The model must **extract a structured value** — never pass raw user text into the content field, which is length-capped.
- Facts flagged safety-critical by their type policy are never consolidated.

### Policy per type

A central policy map is the source of truth for each fact type:

```go
FactMyType: {
	AllowedWriters:    []AIRole{...},
	DefaultTTLDays:    intPtr(N),   // nil = permanent
	DefaultReviewDays: intPtr(N),
	Supersedable:      true/false,
	SafetyCritical:    true/false,
},
```

Types range from permanently valid and safety-critical, through medium-lived entries with a review date, to short-lived observational ones.

### Temporal fields

| Field | Effect |
| --- | --- |
| valid-until | Auto-expiry |
| review-due-at | Marks the fact as needing review |
| supersedes / superseded-by | Version chain |

### Rotation — five mechanisms that combine

1. **Schema-level TTL** per type in the policy map.
2. **Review dates** flip a fact to needs-review; the system prompt then receives a block instructing the agent to confirm it unobtrusively.
3. **Supersede on versioning** — a new fact of the same scope invalidates the old one automatically.
4. **Explicit negation** — the user says the condition resolved and the model archives it with a reason.
5. **A background rotation worker** auto-expires past validity and marks reviews due.

### Adding a fact type

1. Add the enum value and register it in the all-types list.
2. Widen the database check constraint **if one exists for that column**.
3. Add its policy entry.
4. Update the writer-matrix table test.
5. Update the plain-text renderer for the new type.

## The pipeline engine

All periodic and queue-backed background work runs on one engine per binary, registered at composition.

### Five trigger types

| Trigger | Fires on |
| --- | --- |
| Cron | A fixed interval — rotation, retention, upgrades, periodic sweeps, engagement ticks |
| User action | An HTTP handler firing a named action |
| Pipeline event | The terminal status of one pipeline, dispatching the next |
| Event bus | A generic listener, used for cross-replica notification |
| Executor | Owns a `FOR UPDATE SKIP LOCKED` queue for its job type and runs a multi-step state machine |

### Adding a pipeline

1. Define the job-state struct in the domain entity file.
2. Implement the step interfaces.
3. Compose it with the constructor taking a name, marshal/unmarshal pair and the steps.
4. Create an executor, register it on the engine and start its run loop.
5. Add an enqueue path — a user-action trigger if HTTP-driven, or an inline dispatch from another pipeline.

### Adding a step

Implement `ID` / `Done` / `SkipIf` / `Run`. `Run` mutates the state in place and returns an action:

| Action | Meaning |
| --- | --- |
| Advance (zero value) | Continue to the next step |
| AwaitUser | Pause until the user acts |
| Halt | Stop this run |
| Dispatch | Dispatch another pipeline |

A non-nil error takes the executor's retry path.

Steps are unit-testable without a database — every dependency is injected.

## Enqueuing from another domain

The producing domain commits its own transaction first. The durable enqueue is synchronous and idempotent; the immediate trigger is asynchronous, detached from the request context so the work survives the client disconnecting. Enqueue errors never reach the response.

## Removing a pipeline

Retiring a subsystem means removing its steps, its executor, its enqueue trigger, its gauges and its crons together. A leftover cron on a deleted job type is a queue that fills and is never drained.
