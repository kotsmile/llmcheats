# Observability — the day-one minimum

<!-- F-039 -->

A never-skip item. You cannot operate what you cannot see, and a change that
needs a new signal opens the devops gate whatever else is true.

## User-level visibility

- **User impersonation** — an admin can see the system as a specific user sees
  it, to reproduce their problem. Behind an admin-only permission, and **every
  impersonation is audited** (who, whom, when). This single feature collapses
  most "works for me" support cycles.
- **Per-user logs and error tracking** — given a user id, pull their recent
  requests, errors and key actions. Request logs carry a user/request correlation
  id.
- **Client-side error reporting** — frontend errors land somewhere you look, with
  the release version attached.

## System health signals

<!-- F-095 -->

- **RED metrics per route pattern**: rate, error percentage, duration. **Route
  pattern, never raw path** — raw paths blow up metric cardinality.
- **Structured logs, centrally queryable.**
- **Performance baselines** — know the normal latency and throughput so an
  anomaly is visible as one.

<!-- F-094 -->

Log levels carry meaning: **401/403 Info, 4xx Warn, 5xx Error.** An auth failure
is not an error of the system; a 500 is.

## Alert severities

<!-- F-093 -->

Exactly two:

- **CRIT** — a person is paged now: service down, error-rate spike,
  data-affecting failure, imminent certificate expiry.
- **WARN** — visible in a channel, handled in working hours: elevated latency,
  disk trending full, retry rates up.

**Anything that would be lower than WARN is a dashboard, not an alert.** Alerts
that do not demand action train people to ignore alerts.

## Health endpoints

Wired into whatever runs the system — a systemd watchdog, a compose healthcheck,
a k8s probe. **The runtime restarts what the metrics only report.**

## Dashboards and alert rules are code

<!-- F-048 -->

They live in the repo, whatever the toolchain. Click-ops drifts and dies, and
where a reconciler owns them, a UI edit is reverted by self-heal without notice.
