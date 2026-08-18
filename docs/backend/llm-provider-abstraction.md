---
title: Provider-agnostic model layer and prompt caching
summary: The provider interface and factory registry, per-flow model selection, and how vendor-specific prompt caching is expressed neutrally.
theme: backend
keywords: [provider interface, factory registry, capabilities, stop reason, translator, prompt caching, cache_control, cache hint, per-flow override, model selection, cost, usage logging, streaming]
related:
  - backend/llm-routing-and-tools.md
  - backend/llm-safety-and-tracing.md
  - backend/go-shared-library-layout.md
---

## The abstraction

The model layer is genuinely provider-agnostic, not a single-vendor wrapper with a thin interface on top:

- A `Provider` interface plus a **factory registry**; each vendor sub-package self-registers in `init()`.
- Several full vendor implementations, plus one aggregator reached over a vendor-compatible transport standard.
- `StopReason` is a **provider-neutral enum**. Each vendor's translator normalises its wire values; call sites compare the neutral enum and **never a vendor literal**.
- `Capabilities()` — the provider declares what it supports (explicit caching, and so on) and callers adapt rather than branching on a vendor name.
- A strict-mode tool-schema validator for the vendors that require one.

## Per-flow model selection

Provider and model are selected **per flow**, not per role, through a config override map. Named seams exist for the interactive agent path, the classifier, a translation path and a curation path; they are resolved at composition time.

Cost reporting: the aggregator returns exact per-call cost, which is written into the usage log table alongside token counts.

A caveat worth knowing: some models lose explicit prompt caching when reached through the aggregator. Prefer the native vendor type for those.

## Per-role provider is not a refactor

The service currently holds a single provider for all agent roles. Adding per-role providers is a map or a dedicated field, plus config and wiring — then running the tool schemas through the strict validator and verifying that cache hints degrade gracefully on vendors without caching.

A different **model on the same provider** is a one-line client construction.

## Prompt caching

Where the vendor supports explicit caching, the request carries:

- **System blocks**, where the last block marked with a cache hint receives the cache marker.
- A **cache-tools flag**, placing the marker on the last tool in the list.

Usage returns cached-input and cache-write token counts, which are logged.

What is cached for agent calls: the static system prompt (role prompt, reference blocks, safety thresholds, unit conventions) and the tool definitions. Classifier and summarisation calls run on the cheap model with no caching — short prompts, low hit rate.

**Caching semantics are vendor-specific.** A translator either maps the cache directive onto the vendor's equivalent or disables it. This is why the master tool list's order is load-bearing: it is the cached prefix.

## Prompt assembly

System prompts are **inline constants** — a deliberate decision for debuggability over template files.

Each agent role is extracted to its own leaf package, one source per role, imported by every flow that needs it. The service keeps only assembly: role selection, the stable/dynamic system-block split that the cache boundary depends on, and shared addenda.

**Leaf rule**: an agent package imports only the standard library (plus, at most, one reference catalogue), never the service package.

A prompt that encodes a reasoning framework — assessment, priority ordering, quality rubric — outperforms one that encodes a lookup table, and it does not go stale when the data behind it changes.

### Editing rules

- Do not rewrite a prompt without discussion; it changes model behaviour.
- After any change, an **evaluation run is mandatory**.
- Prompt changes need no schema migration.
- Prompts quote external guidelines verbatim — do not delete the citations.
- Do not change the assembly structure without evaluation; it affects every role at once.

### Runtime assembly

A role whose prompt is concatenated from several blocks declares that order in one assembly file, which is also the order to read them in. The assembled prompt is built **once at construction** and cached on the service, not rebuilt per request.

When a static catalogue moves out of a prompt into an on-demand tool, keep the constructor parameter: callers stay unchanged and the same source wires the tool. Add a prompt block instructing the model to fetch the reference before acting on it.

## Streaming and tool schemas

- Streaming: server-sent events into a delta channel.
- A tool's input schema is raw JSON; each vendor translator normalises it.

## Cost discipline

Do not add a model call without accounting for cost. The capable model is one to two orders of magnitude more expensive per call than the cheap one — **default to the cheap model for meta work** (classification, routing, summarisation) and reserve the capable one for user-facing generation.

## Testing

- Table-driven unit tests with arrange/act/assert comments.
- Tool parsers: mandatory, they are the input validation boundary.
- Tool executors: with mocked dependencies.
- **Do not test prompt contents directly** — flaky and rewritten often.
- Evaluation is a separate level, run after any change to prompts, tools or routing.

## Common mistakes

- Calling a provider method without a nil guard — in tests and partial DI it may be nil.
- Writing a vendor literal into service code instead of the neutral constant.
- Changing the tool-use stop-reason handling without understanding that it is the multi-vendor seam.
