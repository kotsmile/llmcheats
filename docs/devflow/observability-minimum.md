---
title: Observability — the never-skip minimum
summary: From day one a system serving clients has user impersonation, per-user logs, client error reporting, RED metrics, meaningful log levels, two alert severities and wired health endpoints.
keywords: [observability, impersonation, per-user logs, correlation id, client error reporting, RED metrics, structured logs, log levels, performance baseline, alerts, CRIT, WARN, dashboard, health endpoint]
related:
  - devflow/principles.md
  - webapp/infrastructure.md
  - devflow/release-speed.md
  - devflow/full-flow.md
---

# Observability — the never-skip minimum

Whatever else is deferred, a system serving clients has these from day one. The
implementation side is in `webapp/infrastructure.md`; this is the floor.

## User-level visibility

- **User impersonation**: an admin can see the system as a specific user sees
  it, to reproduce their problem — behind an admin-only permission, and **every
  impersonation is audited** (who, whom, when). This single feature collapses
  most "works for me" support cycles.
- **Per-user logs and error tracking**: given a user id, you can pull their
  recent requests, errors, and key actions. Request logs carry a user/request
  correlation id.
- **Client-side error reporting**: SPA errors land somewhere you look (an
  error-tracking service or your own endpoint), with release version attached.

## System health signals

- HTTP RED metrics per route pattern: rate, error percentage, duration.
- Structured logs, centrally queryable; log levels that mean something (401/403
  Info, 4xx Warn, 5xx Error).
- Performance baselines: know the normal latency/throughput so anomalies are
  visible.

## Alert severities

Exactly two:

- **CRIT** — a person is paged/pinged now: service down, error rate spike,
  data-affecting failures, certificate expiry imminent.
- **WARN** — visible in a channel, handled in working hours: elevated latency,
  disk trending full, retry rates up.

Anything that would be lower than WARN is a dashboard, not an alert. Alerts that
do not demand action train people to ignore alerts.

## Health endpoints

Wired into whatever runs the system (systemd watchdog, compose healthcheck, k8s
probes) — the runtime restarts what the metrics only report.
