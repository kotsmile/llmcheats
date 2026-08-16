# 8. New-application checklist

**Backend**
- [ ] `cmd/<app>/main.go` with `run() error`, `serve`/`migrate` subcommands
- [ ] Domain packages: `entity/`, `service/`, `infra/`, `transport/http/`
- [ ] Value objects with validating constructors; invariants in entity methods
- [ ] Ports declared in `service`, implemented in `infra`, with `var _ Port = (*Impl)(nil)`
- [ ] `TxFactory.WithTx`; explicit `tx` params; mutate → commit → side effects
- [ ] Typed errors (status-carrying or sentinels+switch); unknown error → opaque 500
- [ ] `ReadJSON` hardening: media-type check (415), size cap (413), unknown fields, trailing garbage, struct validation
- [ ] Middleware order: Recover → SecureHeaders → logging/metrics → timeout groups → per-route auth
- [ ] 10s default deadline; carve-outs justified; streaming outside the timeout group
- [ ] `WriteTimeout` ≥ longest carve-out; drain window = `WriteTimeout`
- [ ] SQL: const query strings, parameterized only, array binding for IN-lists
- [ ] Migrations: SQL files, embedded, applied by `migrate` step pre-deploy, expand→contract
- [ ] Config: one YAML, `${VAR}` secrets, fatal on unset, `Default()` + validation, never logged
- [ ] Config-parses test + secrets-via-placeholders test
- [ ] Metrics on a separate listener; `/health`

**Frontend**
- [ ] Vite + TS strict + Tailwind 4; `tsc -b && vite build`
- [ ] Dev proxy mirrors production proxy paths
- [ ] `window.__RUNTIME_CONFIG__` runtime config
- [ ] FSD layers scaled to app size; imports through slice `index.ts`
- [ ] Lazy routes; guard component with init→authn→authz→state order
- [ ] TanStack Query + central query keys; mutations invalidate by key
- [ ] Audited/side-effectful reads as mutations; sensitive values never cached
- [ ] Zustand for client state only; selector-based consumption
- [ ] Cookie auth: no tokens in storage; three-way refresh verdict; single in-flight refresh
- [ ] Semantic design tokens; dark/light via `<html>` class + pre-React inline script
- [ ] No manual memoization; no `any`; no suppression comments

**Security**
- [ ] HttpOnly + Secure + SameSite=Lax on every cookie; refresh cookie path-scoped
- [ ] No state-changing GET routes (audit explicitly)
- [ ] Backend rejects non-JSON `Content-Type` on JSON routes (415 — the CSRF leg)
- [ ] Security headers middleware + CSP at the proxy
- [ ] AuthZ: route gates (403, no redirect) + service-level resource checks + entity perms
- [ ] Auth-path rate limiting (per-account counters, 429 + retry_after)
- [ ] Secrets: manager → env → `${VAR}`; response redaction; `no-store` on secret responses
- [ ] AES-GCM for sensitive data at rest; key length validated at startup
- [ ] Audit log append-only by construction; audit-before-disclosure where relevant
- [ ] Never fail open on missing auth config

**Testing**
- [ ] Each non-trivial test states its reason; AAA comments
- [ ] Hand-written fakes (nil-embedded interfaces); no mock frameworks
- [ ] DB tests env-gated/build-tagged, each justified ("worth a database because…")
- [ ] Handler tests: real router + dev-mode auth + fake stores; assert the authz matrix
- [ ] E2E: composed stack, public client, golden paths, own CI job
- [ ] Frontend logic in pure modules, tested with the platform's plain runner

**Infrastructure**
- [ ] Runtime-agnostic contract: env + config file + network + SIGTERM
- [ ] Static binary, multi-stage image, one artefact per service
- [ ] Migrations as a distinct pre-serve step in whatever runs it
- [ ] Structured logs to stdout; metrics scraped privately; health endpoints
- [ ] Releases are immutable tagged artefacts; deployed state is declarative and diffable

**AI (only if the product has LLM features — `webapp/9-ai-features.md` §9)**
- [ ] Prompts live in code, reviewed; stable prefix ordered for caching
- [ ] LLM provider behind a service port; hand-written fakes for tests
- [ ] Tool executors validate arguments + authz like a public endpoint
- [ ] Conversations encrypted at rest, access audited, never plaintext in logs
- [ ] Level-1 deterministic tests blocking in CI; Level-2 scenario evals recorded
- [ ] LLM calls under justified deadline carve-outs; post-LLM writes survive cancellation
