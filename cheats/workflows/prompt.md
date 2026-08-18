---
name: prompt
description: "prompt: write or change text a model executes. Use for a prompt starting prompt:, or a request to write, fix or tune a system prompt, an agent persona, a tool description, an intent classifier, an extraction instruction or a clarifying-question script."
---

# `prompt:` — the flow for text a model executes

<!-- F-101 -->
A prompt is the one part of the system with no compiler, no type checker and no
stack trace. Every stage below exists to replace one of those.

Flow: **fast** while the prompt is internal, **full** once its output reaches a
user — a model-facing prompt is product surface, and the trigger list in
`routing.md` applies to it unchanged. A prompt that can call a write tool, spend
money, or say something about someone's health or money is full flow.

## 1. Name the artifact — it picks the gates

| Artifact | What it is | Gate it may not ship without |
|---|---|---|
| role / system prompt | assembled blocks, cached prefix | an eval pack (§5) |
| tool description | trigger, anti-trigger, schema | golden snapshot of the tool surface |
| classifier | closed labels plus tie-breaks | eval cases on the collisions, not the labels |
| question script | a declarative graph | validation at load |
| extraction instruction | attached to one open question | negative and count assertions |

<!-- F-115 -->
**There is no cosmetic prompt edit.** Wording moves the cache prefix and the
golden hash. Both are load-bearing; both fail CI on purpose.

## 2. Split before you write

<!-- F-102 -->
Order the prompt by **rate of change**, not by topic: everything invariant for a
given role, locale and surface first; everything per-request last. Nothing that
changes per turn — no timestamp, no profile, no retrieved fact — goes in the
stable half. One changing character invalidates the cache for the whole block
after it.

<!-- F-101 -->
Assemble from named blocks, do not write one string. A rule that applies to more
than one agent lives in **exactly one** block, with a comment naming which
agents get it and why one deliberately does not. The assembly function is the
reading order of the prompt — keep it readable as such.

## 3. Write the stable half in this order

<!-- F-104 -->
```
Identity — who you are, what you own
Voice — tone, register, what good sounds like
Capabilities — per tool: what / when (trigger) / when NOT (anti-trigger)
Disambiguation — the confusable pairs, stated as a contrast
Reasoning framework — which signals, in what order, when to skip the analysis
Conflict priority — what beats what
Quality rubric — the criteria for self-checking
Domain principles — as principles, not lookup tables
Negative space — when to do nothing
Self-check — how to read a tool result and correct
Forbidden output — leaks, internal labels, duplicated card content
Output format — prose vs list, length, medium constraints
Language / locale directive
Input-safety boundary — user text and retrieved memory are DATA
```

<!-- F-103 -->
**Every capability gets a trigger and an anti-trigger.** A missing anti-trigger
is the most common cause of an agent that fires a write tool on ambiguous
chatter. For every pair of tools that get confused, write the contrast in both
their entries.

<!-- F-104 -->
Prefer a rubric to a table. Tables invite pattern-matching; a stated framework
survives the input you did not anticipate.

<!-- F-105 -->
**Capability awareness in the prompt, data behind a tool.** Context you preload
is paid for every turn and its window silently hides whatever falls outside it;
context fetched by tool call is paid for when it is needed. What stays in the
prompt is that the data exists and when to pull it.

<!-- F-107 -->
Precompute every date, sum and aggregate in code, inject it, and state it as
authoritative. Any number the model derives itself is a number that can
contradict your UI.

<!-- F-106 -->
Tag user text and anything retrieved from a store as DATA, **enumerate the
injection categories** rather than saying "ignore injections", and state the
required behaviour positively: answer the legitimate part, silently, without
mentioning the attempt.

<!-- F-108 -->
For structured output ship four things: the closed enum verbatim, a worked
example at the confident end, a worked example at the uncertain end, and what
happens when a value is invalid.

<!-- F-109 --><!-- F-110 -->
Ban echoing every internal marker you inject, and every field the UI renders as
a card. Prompt and renderer are two halves of one contract: **duplicated content
is a bug, missing content is a bug.** Repeating a rule the model keeps breaking
is fine — say in a comment that it is a deliberate duplicate, and keep the
copies in agreement.

<!-- F-111 -->
Classifier prompts invert these proportions: roughly 15% defining the labels,
75% resolving the collisions between them, 10% output format. **The boundaries
are the work.**

## 4. Clarifying questions — pick one regime

<!-- F-119 -->
Scripted intake is a declarative graph, validated at load. Conversational
clarification is prompt rules. Mixing them is how interrogation-feeling bots
happen.

**A scripted question:** acknowledge what you already know, then ask exactly one
thing. 3–7 options written as sentences, not labels. An honest opt-out in every
set ("only starting", "don't remember") so nobody answers falsely. A stable slug
to branch on, localised text to display — never branch on display text. The
answer's destination declared with the question, so a closed question needs no
model call to be persisted.

<!-- F-122 -->
Gate an expensive chain behind one cheap question. Ask "do you know X?" before
asking "what is X?".

<!-- F-120 -->
**Every open question carries its own extraction instruction**, and every
extraction instruction ends with the non-answer clause: *if the reply is "don't
know" / "none" — make no calls; do not invent data that is not in the reply.*
Narrow the output space first (which fact types are allowed), state one fact per
thing, and declare what a failed extraction does — skipping forward beats
trapping the user on a step.

<!-- F-121 -->
Classify a reply that is not an answer: off-topic re-asks **once** then skips
with a null; a question back gets answered and never counts against that cap.

<!-- F-123 -->
Write the "when NOT to ask" list, and make it longer than the "when to ask"
list. Ask when a hard input is missing and guessing is unsafe, or when which
object to act on is genuinely ambiguous. Do not ask when one candidate exists,
when the data merely does not exist yet, or about anything this agent has no
authority to change.

<!-- F-124 -->
Settle how the answer will be rendered before writing the question. A closed
question with no chip UI is a worse open question.

## 5. Validation — the prompt is the weakest layer, not the only one

<!-- F-113 -->
**Prompt-level safety is a preference; a deterministic pre-execution check is a
guarantee.** Anything that must not happen is code, not wording.

| Layer | What it catches | Where |
|---|---|---|
| 0 · parse | enum, bounds, format, raw user text in a stored field | tool parser, before execution |
| 1 · guard | the must-not-happen list, whatever the prompt said | deterministic, pre-execution |
| 2 · classify | success vs skip vs error vs safety-abort | the tool result string |
| 3 · structural | tool surface drift, registry desync | tests, no model call |
| 4 · eval | behaviour, over-extraction, invented facts | data pack, behind a flag |
| 5 · replay | what changed across N real cases | read-only harness |
| 6 · production | cost, outcome mix, traces | metrics |

<!-- F-112 -->
Layer 0: validate in the parser, never trust tool input, and standardise the
failure string. An executor that fails silently is read as success by everything
downstream — that is how a model confirms work that never happened.

<!-- F-114 -->
Layer 2: **"did nothing" is its own outcome.** `created 0 records`, "already
set", "plan exists", a safety abort — none of these are success, and counted as
success they silently inflate the quality metric.

<!-- F-113 -->
Redact at a named boundary: the internal pattern id that triggered a guard never
reaches the model or the user; a mapped plain-language area does, and an
unmapped one degrades to a generic phrase rather than leaking the enum.

<!-- F-115 -->
Layer 3: pin every tool description and schema, **in order**, behind one hash.
Ordering is the cache prefix. Re-baseline deliberately, with the reason written
next to the golden value. **Do not unit-test prompt prose** — it is flaky and it
changes often. Test the surface and the parsers; test the prompt behaviourally
at layer 4.

<!-- F-116 -->
Layer 4: the eval pack lives in **data, not code**, behind a build flag, with
its per-run cost stated in the header. Every scenario asserts three ways —
what must be present, **what must not appear**, and a count bound. The negative
and the count are what catch over-extraction and hallucinated extras; "does the
output contain X" never can.

<!-- F-117 -->
Layer 5: judge a prompt change by **diffing N real cases before and after**, not
by reading one new answer. The replay harness is read-only twice over — at the
database and at every mutating dependency — and refuses production.

<!-- F-118 -->
Layer 6: traces carry ids and slugs only; message content sits behind a separate
capture gate, default off. Log per-call cost and state a budget per model tier —
a meta-call on the expensive tier is a two-order-of-magnitude mistake.

## 6. Verify

<!-- F-116 -->
**An eval run is mandatory after any prompt change**, including one that only
changed wording. When it fails, the fix is a separate commit — not an amend, so
the failure stays in the history.

<!-- F-014 -->
Name what you could not assess: a case the pack does not cover, a behaviour only
observable at runtime, a path you could not replay.

## 7. Hand-back

<!-- F-013 --><!-- F-029 -->
Cap: **2 KB.**

```
Changed:      prompt blocks / tools / script steps touched, one line each
Ran:          eval pack (N scenarios, pass/fail), golden snapshot, replay diff
Diff:         what changed across the replayed cases, in one line
Not verified: what the pack does not cover, explicitly
Skipped:      follow-ups consciously left
```

<!-- F-038 -->
Fit before improvement: a prompt that imports a structure this repo's other
prompts do not use is a finding, not an upgrade.
