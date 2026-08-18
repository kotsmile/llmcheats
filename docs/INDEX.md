# INDEX — the llmcheats reference

Routing table only. Every fact lives in the file it points at. One topic per
file; every file opens with YAML front-matter carrying its summary, keywords and
related files.

**Read only the files your task needs.** Read the file before acting — do not
work from memory of it.

## The six groups, and how much authority each has

The corpus has two origins, and the difference decides how much weight a file
carries in *your* repo.

| Group | Origin | Authority |
|---|---|---|
| `webapp/` | the guide — how to build a web application | **pattern**, unless the line says constraint |
| `devflow/` | the guide — in what order, with which gates | **process**, applies everywhere |
| `backend/` `frontend/` `devops/` `tools/` | distilled from one production monorepo | **pattern**, read only on a stack match |

<!-- the distinction this table encodes is the reference's own: devflow/principles.md -->
A **constraint** holds in every project; deviating from one is a vulnerability
and needs a written reason. A **pattern** is how this reference does it, and a
project that already builds differently keeps its own architecture — consistency
with the surrounding code wins. The line between them is in
`devflow/principles.md`.

The last four groups describe **one** system: Go services, React and React
Native apps, GitLab-style CI, an Argo-style reconciler, an internal secrets
console. Service endpoints, credentials, cloud resource identifiers and
product-domain specifics are deliberately absent. Where a doc and the code
disagree, the code wins.

---

## `webapp/` — how to build

| path | purpose | read this when… |
|---|---|---|
| `webapp/system-shape.md` | Reference topology and the one-origin rule | standing up a new app or changing deploy topology |
| `webapp/backend-layers.md` | The four domain layers and dependency direction | laying out a backend package tree |
| `webapp/backend-entities.md` | Value objects, invariants, sentinel errors | writing domain types or business rules |
| `webapp/backend-services.md` | Use cases, ports, transaction boundaries | writing a use case or wiring a dependency |
| `webapp/backend-infrastructure.md` | Raw SQL, transaction factory, migrations | writing queries, repositories or migrations |
| `webapp/backend-transport.md` | Handlers, DTOs, middleware order, guards | adding an endpoint or touching the router |
| `webapp/backend-errors.md` | The status-carrying AppError and propagation | designing or debugging error handling |
| `webapp/backend-config-lifecycle.md` | Layered YAML config, startup and shutdown | adding config or changing process lifecycle |
| `webapp/backend-python.md` | The same architecture in FastAPI/SQLAlchemy | building the backend in Python |
| `webapp/frontend-toolchain.md` | Vite, TS strict, Tailwind, runtime config | bootstrapping or configuring an SPA |
| `webapp/frontend-structure.md` | FSD layers, routing, route guards | placing a file or adding a route |
| `webapp/frontend-data.md` | API client and TanStack Query | fetching, caching or mutating server data |
| `webapp/frontend-state.md` | Client state in Zustand | holding client-only state |
| `webapp/frontend-auth.md` | Cookie session, 401 refresh, OIDC redirects | signing users in or handling a 401 |
| `webapp/frontend-ui.md` | Design tokens, theming, forms | styling a screen or building a form |
| `webapp/frontend-react.md` | React 19 conventions | writing components or chasing re-renders |
| `webapp/testing-strategy.md` | What to test, in what order, and when not to | deciding whether a test is worth writing |
| `webapp/testing-unit-fakes.md` | Go unit tests and hand-written fakes | writing unit tests or a test double |
| `webapp/testing-database.md` | When and how to test against Postgres | the SQL itself is the risk |
| `webapp/testing-http-e2e.md` | Handler tests and the e2e suite | testing endpoints or the composed stack |
| `webapp/testing-frontend.md` | Frontend tests and the pure-logic discipline | testing SPA logic or fixing a UI bug |
| `webapp/testing-ci.md` | Check jobs and what blocks a merge | wiring or changing CI checks |
| `webapp/security-authentication.md` | JWT, OIDC, machine tokens | building or reviewing authentication |
| `webapp/security-authorization.md` | Four authz layers, roles, SQL filters | deciding who may do what |
| `webapp/security-input-sql.md` | Validation gates and parameter binding | accepting input or writing a query |
| `webapp/security-secrets.md` | Secret delivery, redaction, encryption at rest | handling credentials or sensitive data |
| `webapp/security-audit-logging.md` | Append-only audit of access and change | the system manages access, money or secrets |
| `webapp/security-http-hardening.md` | Headers, CORS, CSRF, rate limiting | hardening the HTTP surface |
| `webapp/security-frontend.md` | Storage, XSS and where authority lives | reviewing SPA security |
| `webapp/performance.md` | DB tuning, deadline budget, concurrency, caching | something is slow or a deadline is wrong |
| `webapp/infrastructure.md` | Runtime contract, shipping, deploy, observability | deploying, packaging or instrumenting |
| `webapp/new-app-checklist.md` | Tick-list per area; Security block reviews a diff | starting an app or reviewing a finished diff |
| `webapp/ai-features.md` | LLM features inside the same architecture | the product has LLM functionality |

## `devflow/` — in what order, with which gates

| path | purpose | read this when… |
|---|---|---|
| `devflow/principles.md` | Never-skip list, pattern vs constraint | deciding how much process a change owes |
| `devflow/roles.md` | Role → agent → what it owns | choosing who does a stage |
| `devflow/full-flow.md` | Thirteen stages with gates and artifacts | delivering a feature or migration |
| `devflow/skip-gates.md` | One skip test per full-flow stage | the full flow is chosen or forced |
| `devflow/release-artifacts.md` | The paper trail and who owns each document | closing out a feature or release |
| `devflow/fast-flow.md` | Seven-stage bug and hotfix protocol | fixing an agreed-broken behavior |
| `devflow/asap-flow.md` | One-pass flow, its triggers and its floor | small urgent work, or deciding it is not |
| `devflow/observability-minimum.md` | What a system must see from day one | planning or auditing observability |
| `devflow/release-speed.md` | Speed as a tested property, with numbers | judging whether you can ship a fix fast |
| `devflow/git.md` | Commit format and PR rules | committing, opening or merging a PR |
| `devflow/scaling-down.md` | Collapsing ceremony without dropping gates | the team is two people |
| `devflow/flow-visibility.md` | Making a running flow observable | a flow runs long or an agent goes quiet |
| `devflow/resuming.md` | Picking up interrupted work | resuming, continuing or finishing work |
| `devflow/agent-io.md` | What one agent pass costs and why | a single pass takes too long |
| `devflow/flow-cost.md` | What a whole flow costs and how to spend less | the process costs more than it should |
| `devflow/project-memory.md` | `CLAUDE.md` / `AGENTS.md` content and limits | recording what the next session must know |

## `backend/` — Go services, data layer, model serving

Read on a Go + layered-architecture match.

| path | purpose | read this when… |
|---|---|---|
| `backend/layered-architecture.md` | Four-layer split, DI, value objects, naming and comment policy | adding a domain or deciding where code belongs |
| `backend/errors-and-panics.md` | Error construction, sentinel grouping, panic policy | returning or wrapping an error |
| `backend/http-endpoints-and-middleware.md` | Handler contract, envelopes, middleware chain, deadlines | adding an endpoint or a long-lived route |
| `backend/authorization-model.md` | Route guards versus operation permissions | adding a role, a route restriction or an ownership check |
| `backend/configuration-loading.md` | One config file, placeholder traps, why env struct tags do nothing | adding a config value or a secret |
| `backend/database-and-migrations.md` | SQL style, index policy, cursor pagination, migration flow | writing SQL or a migration |
| `backend/websocket-hub.md` | Hub over pub/sub, encrypted storage, drop-on-overflow | changing the socket or streaming to a client |
| `backend/code-generation.md` | Which artefacts are generated and why nothing depends on generation | you changed a spec or an annotation |
| `backend/go-shared-library-layout.md` | What belongs in the shared library and the `<service>x` convention | you need a shared helper or are placing a client |

## `frontend/` — React, React Native, shared packages

Read on a TypeScript + React match. The `mobile-*` files need React Native.

| path | purpose | read this when… |
|---|---|---|
| `frontend/typescript-react-conventions.md` | Strictness, styling, state and token rules | writing frontend code anywhere |
| `frontend/feature-sliced-architecture.md` | Layers, import direction, and routing beside them | placing a new file or a new slice |
| `frontend/web-app-patterns.md` | Lazy routes, cookie auth, runtime base URL, theme flash | working in a web SPA or an isolated site |
| `frontend/query-cache-and-invalidation.md` | Prefix invalidation, why refetch is wrong, overscroll refresh | data looks stale, or adding a query hook |
| `frontend/shared-packages-and-platform-adapters.md` | Package set, no-DOM rule, refresh verdict, dual-output builds | changing a shared package or the API client |
| `frontend/mobile-stack-and-routing.md` | Native stack, route tree, persistence, keyboard, list choices | working in the mobile app |
| `frontend/mobile-ui-pitfalls.md` | Styling and animation traps that compile and still fail | a mobile change renders but behaves wrong |
| `frontend/mobile-widget-verification.md` | Widget constraints, the three verification gates, empty states | changing a home-screen widget |

## `devops/` — CI, deployment, access, secrets

Read on a GitLab-style CI or reconciler-owned-deploy match.

| path | purpose | read this when… |
|---|---|---|
| `devops/release-tagging-and-gitops.md` | What a tag triggers and where a green pipeline changes nothing | shipping a version or a deploy did not land |
| `devops/ci-pipeline-composition.md` | Recursive includes into one flat pipeline, rules, templates | adding or restructuring a CI job |
| `devops/ci-performance-model.md` | Measured cache, clone and runner-tier cost model | a job is slow, queued, or OOM-killed |
| `devops/service-config-in-charts.md` | Verbatim config rendering and the two substitution mechanisms | adding a chart value or a config placeholder |
| `devops/secrets-and-delegation.md` | Machine credentials, revocation, and the two-writer prune trap | issuing a machine credential or running a sync with prune |
| `devops/rbac-role-grammar.md` | Management versus enforcement planes, disjoint levels, approvals | designing or renaming a role scheme |
| `devops/internal-network-and-admin-access.md` | Issued credentials, credential files, environment-scoped sessions | distributing credentials or marking a privileged shell |

## `tools/` — developer workflow

Read always. Commits and dependency handling are not stack-specific.

| path | purpose | read this when… |
|---|---|---|
| `tools/commit-conventions.md` | Commit format, branch/PR rules, comment, function and test rules | about to commit or open a PR |
| `tools/dependency-management.md` | Adding dependencies per ecosystem and the runtime version barrier | adding a dependency, or type errors appeared in untouched files |

---

## Rules

Read the relevant file before acting — do not work from memory of it.

Deviating from a **constraint, a security rule, or a triggered workflow gate**
needs a written reason; silently deviating from one is never allowed. An ordinary
implementation choice — naming, file layout, which of two equivalent idioms — is
**not** a deviation and needs no paragraph defending it. The line between the two
is in `devflow/principles.md`.

## Maintaining this index

**Every file added to, renamed in, or removed from `docs/` updates this index in
the same change.** An edit that changes a file's purpose, keywords or `related`
front-matter updates its row too. A doc no index points at is a doc no agent will
find.
