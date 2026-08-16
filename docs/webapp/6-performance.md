## 6.1 Database

**Connection pool** — one shared helper with deliberate bounds:

```go
db.SetMaxOpenConns(cfg.MaxConns)
db.SetMaxIdleConns(cfg.MaxConns / 2)
db.SetConnMaxLifetime(30 * time.Minute)
db.SetConnMaxIdleTime(5 * time.Minute)
```

Bounded lifetime/idle-time matters behind managed poolers that recycle
connections; the `BEGIN` retry (§2.4) absorbs the recycling moment.

**Indexes**: composite, ordered to match the query — a feed reading
`order by at desc, id desc` gets `(resource, at desc, id desc)` (the
tiebreaker column belongs in the index too); a uniqueness rule
gets a unique index that also backs the upsert. Every index has a written
justification; FK columns you join on get one (Postgres won't).

**N+1 avoidance** — set-based queries are the default:

- "Everything this subject can see" is **one** query with
  `subject = any($1)` over the expanded subject list — never a query per group.
- Its counterpart: the single-resource authorization read is a deliberately
  narrow query on the exact composite index, not "list everything and filter".
- Join in SQL or fetch two sets and join in a map in Go — never loop-and-query.
- "Least-loaded assignee" is one `LEFT JOIN … GROUP BY … ORDER BY COUNT` —
  not a fan-out.

**Work queues in Postgres**: `FOR UPDATE SKIP LOCKED` for multi-replica job
claiming — every replica ticks, the claim query stops duplicate processing.
One job per claim keeps lock scopes small.

**Caps everywhere**: every list endpoint clamps `limit` server-side.

## 6.2 HTTP deadlines: the budget system

Deadlines are a **budget hierarchy**, each level justified:

| Level | Value | Why |
|---|---|---|
| Handler default | **10s** (timeout middleware, cancels `r.Context()`) | the request/response norm |
| Named slow routes | 45–60s per route-group carve-out | uploads, synchronous AI calls — each with a written reason |
| Streaming routes | none (outside the timeout group) | a buffering timeout handler breaks streaming. `WriteTimeout` still applies to any **non-hijacked** stream (SSE, long downloads) — extend the deadline per write with `http.NewResponseController(w).SetWriteDeadline`, or serve streams from a second `http.Server` with `WriteTimeout: 0`; hijacked websockets are exempt |
| `WriteTimeout` | ≥ longest carve-out (75s) | a socket deadline below a handler deadline closes the connection mid-handler and the proxy reports 502 |
| `ReadHeaderTimeout` / `IdleTimeout` | 15s / 60s | Slowloris and keep-alive hygiene. `ReadTimeout` stays **0** — it bounds header *plus entire body*, so 15s would kill the 45–60s uploads regardless of the handler carve-out; upload routes set per-request body deadlines via `http.NewResponseController(w).SetReadDeadline` |
| Shutdown drain | = `WriteTimeout` | a shorter drain drops the requests the carve-outs allow |
| Outbound calls | explicit `context.WithTimeout` ~10s + `io.LimitReader` on response bodies | no unbounded dependency |

The trap the budget prevents: a handler that finishes its externally slow work
just under the deadline, then opens a trailing transaction on an
already-cancelled context — failing with a 500 the client retries into
duplicates. Set the carve-out for the *whole* handler, not the slow call.

At minimum set `ReadHeaderTimeout` (Slowloris) on every server, including
internal ones — and give internal services real write/idle timeouts and
per-request deadlines too; "internal" is not a deadline exemption when it
calls cloud APIs that hang.

## 6.3 Concurrency

- **errgroup as process supervisor** (§2.8) and as a fan-out primitive for
  parallel independent work (calling three providers, composing panels).
- **Cross-replica distribution is the database** (`SKIP LOCKED`), not an
  in-process queue — replicas then need no coordination.
- `context.WithoutCancel` for work that must outlive its trigger: post-commit
  hooks, shutdown drains, coalesced refreshes — always with its own timeout.
- **singleflight** for stampede-prone lookups (session refresh, identity
  resolution): five concurrent requests must cost one upstream call.
- **Bounded in-process caches**: mutex + map, keyed by digest, entries expiring
  with the data they mirror, swept on write. A polling caller should cost one
  upstream round trip per TTL, not per request.
- Never a bare `go func()` in request paths: panic-recovering spawn helper or
  a bounded pool that reports "busy".

## 6.4 Caching

- **Redis** for: auth counters, single-use token registries, pub/sub across
  replicas, expensive-to-recompute catalogs.
- **Derive TTLs from upstream expiry**: cache a signed URL for **half** its
  validity window so eviction always precedes expiry, and treat a hit whose
  remaining validity is under a threshold as a miss ("never hand out a URL
  that may die mid-use"). Emit cache refresh reasons (`miss` / `near_expiry`)
  as metric labels.
- **Don't cache**: high-cardinality cheap queries (search results), and
  **never** revealed secrets — on either side of the wire.
- Frontend caching is TanStack Query's `staleTime` tiers (§3.4).

## 6.5 Frontend

- **Lazy-load every route** (product apps). A small internal console may ship
  one bundle but should split its *login* entry so the sign-in screen needs no
  session and fires no query.
- Pin one React version across the workspace (`resolutions`/`overrides`) and
  `dedupe` react/react-dom in Vite — duplicate React is a correctness bug that
  presents as a perf bug.
- `refetchOnWindowFocus: false`, `retry: 1` as defaults; `staleTime` by
  volatility; mutation → targeted invalidation, not refetch-all.
- No hand memoization (§3.9); if lists get large, virtualize; fix data shape
  before adding `memo`.
