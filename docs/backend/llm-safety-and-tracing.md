---
title: Model input safety and trace observability
summary: The two deterministic input-side safety layers with their structural gaps, and the tracing contract with its non-PII invariant.
theme: backend
keywords: [safety layer, red flag, yellow flag, regex, block, escalate, warn, contraindication, tool input guard, output filter, OpenTelemetry, OTLP, baggage, span processor, trace identity, PII, capture content]
related:
  - backend/llm-routing-and-tools.md
  - backend/llm-provider-abstraction.md
  - backend/llm-memory-and-pipelines.md
---

## Safety is input-side only

Two deterministic layers. **Neither inspects model output.**

| Layer | What it checks |
| --- | --- |
| L1 — input safety | Regex red-flag and yellow-flag patterns over the user's message |
| L2 — tool guard | Tool INPUT validated against structured contraindications before execution |

L1 returns a verdict struct — action, level, reason, user-facing message:

| Level | Action | Effect |
| --- | --- | --- |
| Red | Block / escalate | The model is **not called**; a fixed message plus regional emergency contacts is returned |
| Yellow | Warn | An addendum is injected into the agent's system prompt |

## The gaps are structural, not incidental

Recorded deliberately so they are not rediscovered as surprises:

- **Single-language patterns.** The regex set covers one language; equivalent phrasings in another pass through.
- **Literal-only matching.** Metaphorical and indirect phrasings are not caught.
- **Anchor drift.** A pattern anchored on one anatomical or topical word misses common synonyms describing the same condition.
- **No coverage for whole life-stage categories** that use their own vocabulary.
- **No output filter at all** — no post-processing pass rejects a banned phrasing the model produced.

The general lesson: a regex layer catches the phrasings its author thought of, and its coverage silently narrows as the user population widens. Treat it as a floor, not a control.

**When adding a safety pattern, an evaluation run over the existing cases is mandatory** — patterns interact, and a broadened one that starts blocking ordinary messages is worse than the gap it closed.

## Trace observability

Tracing is **OpenTelemetry with an OTLP/HTTP exporter**, not a vendor SDK. A decorator wraps any provider and emits one client span per completion call.

**Wrap every model client at composition**, or its calls are untraced.

Setup is a no-op when the exporter endpoint is unset — the production default, so the instrumentation costs nothing where it is not configured.

## Making a trace identifiable

Call the trace-context helper **once at the flow entry point**, before the first traced call:

```go
ContextWithTrace(ctx, TraceContext{UserID, SessionID, Flow, Tags})
```

It sets OpenTelemetry baggage. A span processor copies that baggage onto **every** span as the backend's mapped attributes — user id, session id, tags, trace name — because the visualisation backend needs them on all spans, not just the root.

Flow slugs are declared constants. A flow with no natural root span wraps its work in an explicit invoke span, so the trace has a meaningful name and client spans do not orphan.

## The non-PII invariant

Baggage and span attributes carry **only non-PII identifiers and slugs**: an opaque user id, a conversation/job/run id or date, a flow slug.

**Never** names, email addresses or message content.

Conversation content stays behind a separate capture gate, default off, written through explicit input/output setters — a distinct path with a distinct switch.

## Checklist when extending

| Change | Required |
| --- | --- |
| New flow | A trace-context call at its entry point |
| New model client | Wrap it at composition |
| New safety pattern | Evaluation over the existing cases |

## Usage accounting

Every call writes a usage row: token counts, cached and cache-write tokens where the vendor reports them, and an estimated or exact cost. This is the table cost questions are answered from — not the provider's dashboard, which cannot attribute a call to a flow.
