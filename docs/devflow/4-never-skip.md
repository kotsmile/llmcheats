# Development Flow — never-skip: observability and release speed

## 6. Observability — the never-skip minimum

Whatever else is deferred, a system serving clients has, from day one:

**User-level visibility**
- **User impersonation**: an admin can see the system as a specific user sees
  it, to reproduce their problem — behind an admin-only permission, and
  **every impersonation is audited** (who, whom, when). This single feature
  collapses most "works for me" support cycles.
- **Per-user logs and error tracking**: given a user id, you can pull their
  recent requests, errors, and key actions. Request logs carry a user/request
  correlation id (`webapp/7-infrastructure.md` §7.6).
- **Client-side error reporting**: SPA errors land somewhere you look
  (an error-tracking service or your own endpoint), with release version
  attached.

**System health**
- HTTP RED metrics per route pattern: rate, error percentage, duration.
- Structured logs, centrally queryable; log levels that mean something
  (401/403 Info, 4xx Warn, 5xx Error).
- Performance baselines: know the normal latency/throughput so anomalies are
  visible.
- **Alerts in exactly two severities**:
  - **CRIT** — a person is paged/pinged now: service down, error rate spike,
    data-affecting failures, certificate expiry imminent.
  - **WARN** — visible in a channel, handled in working hours: elevated
    latency, disk trending full, retry rates up.
  - Anything that would be lower than WARN is a dashboard, not an alert.
    Alerts that don't demand action train people to ignore alerts.

**Health endpoints** wired into whatever runs the system (systemd watchdog,
compose healthcheck, k8s probes) — the runtime restarts what the metrics only
report.

---

## 7. Release speed — the never-skip capability

Release speed is a **tested property**, not an aspiration:

- Big systems (CI pipeline, orchestrated deploy): a hotfix goes from commit to
  production in **under 30 minutes**.
- Hand-rolled systems (a VM, SSH, a deploy script): **under 5–10 minutes**.

What that requires in practice:

- The deploy path is one command (`deploy.sh prod` or a CI button), documented
  where the code lives, and **exercised routinely** — the fast path must be the
  normal path, or it won't work under pressure.
- Rollback is one command, and it is listed in every release record.
- CI pipelines are lean: a hotfix does not wait for a 40-minute exhaustive
  suite — it runs the fast blocking checks; the exhaustive suite runs after,
  and a failure there rolls forward with another fix.
- No human-memory steps: if deploying needs "the thing only one person
  knows", the system fails the speed test. Scripts remember; people don't.

CI is the preferred automation, but **a shell script driving SSH is a valid CI
replacement** for small systems — same rule applies: it lives in the repo, it
is the only way anyone deploys, and the README points at it.
