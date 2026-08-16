# 7. Infrastructure

The application must not care how it is run. **systemd on a VM, Docker
Compose, Kubernetes, a PaaS — all are equally valid runtimes**; choose by
team size and operational maturity, not fashion. Everything below is written
to hold under any of them.

## 7.1 The contract between app and runtime

Whatever runs the app provides exactly four things:

1. **Env vars** holding secrets (referenced as `${VAR}` in the config file).
2. **A config file** (baked default + optional mounted/overlaid environment file).
3. **A network** to Postgres/Redis/object store and an ingress for HTTP.
4. **SIGTERM with a grace period** ≥ the app's drain window.

The app in turn guarantees: it boots read-only (no writes outside its data
stores), listens on configured addresses, exposes `/health`, drains on
SIGTERM, and logs structured lines to stdout. That contract is the whole
portability story — it is why the same binary runs under systemd
(`EnvironmentFile=` + `ExecStart=app serve --config /etc/app/config.yml`),
Compose (env + mounted config), or Kubernetes (Secret → env, ConfigMap →
mount) without a code change.

## 7.2 Build and ship

- **Static binaries** (Go: `CGO_ENABLED=0`) run anywhere — alpine, debian,
  scratch, a bare VM.
- Multi-stage Dockerfiles: deps layer (dependency download, cached) → build
  layer → minimal runtime stage copying artefacts only. Build tooling never
  ships in the runtime image.
- One image per service; the migrate entrypoint is the same binary
  (subcommand), so shipping one artefact ships both.
- SPA: build once; environment specifics arrive at runtime via the overlaid
  `config.js` (§3.1) — **one artefact serves every environment**.
- Daemonless builders (kaniko/buildah) if CI runners are unprivileged;
  describe the image declaratively enough that swapping builders is a CI
  change, not a per-project change.

## 7.3 Reverse proxy topology

One proxy in front (§1): nginx/caddy as a systemd service, a Compose sidecar,
or an Ingress — same three rules everywhere:

- static SPA files with long-cache hashed assets and no-cache `index.html` +
  `config.js`;
- `/api` (and `/auth`) proxied to the backend; websocket upgrade where needed;
- CSP and any additional headers for the HTML at this layer.

TLS terminates here (certbot/ACME on a VM, cert-manager or LB certs on k8s).

## 7.4 Migrations in deployment

The migrate step runs **before** the new code serves, as its own step:

- systemd: `ExecStartPre=app migrate --config …` (or a deploy-script step)
- Compose: a one-shot `migrate` service the app `depends_on`
- Kubernetes: an init container or a pre-sync hook Job

The app never migrates on serve-boot: N replicas racing DDL is a failure mode
you simply delete by keeping the step separate. Consequence discipline:
migrations are **backward compatible one release back** (the old code runs
against the new schema during rollout) — expand → migrate → contract.

## 7.5 Secrets in deployment

The pattern is runtime-agnostic: **secret store → runtime secret → env var →
`${VAR}` in config**.

- systemd: `EnvironmentFile=/etc/app/secrets.env` (root-owned, 0600)
- Compose: env file or Docker secrets
- Kubernetes: Secret (ideally synced from a cloud secret manager by an
  operator such as External Secrets) → `envFrom`

One flat secret map per app+environment (`myapp-prod`). Never bake secrets
into images or commit them to the repo; changes to a secret are audited in
the secret store, not in git.

## 7.6 Observability

- **Structured JSON logs to stdout**; the runtime ships them (journald,
  logging driver, log agent). Request logs carry method, route *pattern* (not
  raw path — cardinality), status, duration, and a request/user correlation
  field. Log levels carry meaning: 401/403 Info, 4xx Warn, 5xx Error.
- **Prometheus metrics** on a separate private port: RED metrics per route
  pattern from middleware, plus domain gauges/counters owned by services.
  Any scraper (Prometheus, agent, cloud collector) works — the app only
  exposes the endpoint.
- **Health**: `/health` for liveness/monitoring, checked by systemd watchdog,
  compose healthcheck, or probes alike. Readiness (where supported) gates on
  dependencies.
- Dashboards/alerts as code in the repo, whatever the toolchain — click-ops
  drifts and dies.

## 7.7 CI/CD principles

- One pipeline per change: checks gated on changed paths; shared-library
  changes re-run dependents.
- **Releases are tags**; the version is stamped into the artefact at build
  time from the tag (`-ldflags "-X main.version=…"`). Artefacts are
  **immutable**: a re-upload of identical bytes is a no-op, different bytes
  under the same version are refused — a fix is a new tag.
- Deploy = update the desired version somewhere declarative (a values file in
  git for GitOps; a systemd unit env + restart via a deploy script; a compose
  file bump). GitOps (Argo CD/Flux) is an excellent pattern for k8s shops —
  the audit trail is git history — but a reviewed deploy script on a VM
  satisfies the same principle: **the deployed state is written down, diffable,
  and rolled back by reverting**.
- Production deploys gate on a manual approval; test deploys are automatic.
- CI secrets are protected variables scoped to protected branches/tags — MR
  pipelines from arbitrary branches never see them.
- Make MR check jobs interruptible (a re-push cancels the stale run); never
  make a deploy job interruptible.
- Measure before caching in CI: a package-manager store cache whose
  restore+archive costs more than the build it saves is a net loss —
  measure the archive step, cache coarse artefacts, or don't.
