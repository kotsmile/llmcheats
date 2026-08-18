---
title: Service layer — use cases, ports, transactions
summary: One Service struct per domain declares its own port interfaces, receives dependencies through a hand-written constructor, and owns transaction boundaries.
keywords: [service, use case, port, interface, dependency injection, transaction, WithTx, side effects, WithoutCancel, cross-domain, ValidateWiring]
related:
  - webapp/backend-layers.md
  - webapp/backend-infrastructure.md
  - webapp/backend-entities.md
  - webapp/performance.md
---

# Service layer — use cases, ports, transactions

## Structuring a service package

- `service.go` — the `Service` struct, **all port interfaces**, the DI
  constructor, optional `Run(ctx)` background loop.
- Sibling files split **by access scope or use-case family**, not by entity:
  `auth.go` (public flows), `account.go` (self-service), `admin.go`,
  `staff.go`, `system.go` (internal helpers).
- One `Service` struct per domain. No per-use-case command/handler classes —
  that is ceremony this scale does not need.

## Declaring ports where they are consumed

```go
// service/service.go
type Persistence interface {
    FindUserByEmail(ctx context.Context, email entity.Email, tx *sqlx.Tx) (entity.User, error)
    FindUserByIDForUpdate(ctx context.Context, id entity.UserID, tx *sqlx.Tx) (entity.User, error)
    SaveUser(ctx context.Context, user entity.User, tx *sqlx.Tx) error
}

type Mailer interface {
    SendRecoveryCodeEmail(ctx context.Context, to entity.Email, code string) error
}
```

Hand-written interfaces, one per collaborator kind. Note the **explicit
`tx *sqlx.Tx` trailing parameter** on persistence methods: the transaction is
passed openly, never smuggled through `context`. `nil` means "no transaction,
use the pool".

## Injecting dependencies by hand

No DI framework. `main.go` builds infra, passes it into `NewService`, passes
services into `NewHandlers`:

```go
func NewService(
    cfg config.UserServiceConfig,
    persistence Persistence,
    mailer Mailer,
    txFactory *pgx.TxFactory,
    logger *zap.Logger,
) *Service
```

Keep dependencies minimal: pass `signingSecret string`, not the whole config
struct, when one field is all the service needs.

## Bounding transactions: mutate, commit, then side effects

The service owns the transaction; infra only receives it:

```go
func (s *Service) DeleteMe(ctx context.Context, userID entity.UserID) error {
    if err := s.txFactory.WithTx(ctx, func(tx *sqlx.Tx) error {
        if _, err := s.persistence.FindUserByID(ctx, userID, tx); err != nil {
            return err
        }
        return s.persistence.DeleteUser(ctx, userID, tx)
    }); err != nil {
        return fmt.Errorf("delete user: %w", err)
    }

    // Post-commit, best-effort: external systems are NEVER called inside the tx.
    if err := s.sessions.RevokeAll(ctx, userID); err != nil {
        s.logger.Warn("revoke sessions after account deletion failed", zap.Error(err))
    }
    return nil
}
```

The ordering rule: **never call an external system inside a database
transaction**. Mutate, commit, then trigger side effects; a failed side effect
is a warning log, not a rollback (design the side effect to be retryable or
reconciled instead).

## Running detached work

Work that must outlive the request uses `context.WithoutCancel(ctx)` plus
either a panic-recovering `SafeGo` helper or a **bounded** worker pool that
returns "busy" at capacity — never a bare `go func()`.

## Wiring cross-domain dependencies

Domain A must not import domain B. When A needs a capability of B, A declares a
tiny interface in its own service package, and `main.go` wires B's service into
it **after construction** via a setter:

```go
// in user/service — user knows nothing about the notification domain
type WelcomeNotifier interface {
    NotifyWelcome(ctx context.Context, userID entity.UserID) error
}
func (s *Service) SetWelcomeNotifier(n WelcomeNotifier) { s.welcomeNotifier = n }
```

Such ports are optional (`if s.welcomeNotifier != nil`) so a build with a
feature disabled degrades instead of crashing. Because the compiler can no
longer catch a forgotten setter, each service exposes a runtime check that
`main.go` calls before serving:

```go
func (s *Service) ValidateWiring() error {
    var missing []string
    if s.welcomeNotifier == nil {
        missing = append(missing, "WelcomeNotifier")
    }
    if len(missing) > 0 {
        return fmt.Errorf("user service: unwired ports: %s", strings.Join(missing, ", "))
    }
    return nil
}
```

Treat this pattern as a **scaling workaround** for a large multi-domain binary,
not a default: with two or three domains, plain constructor parameters are
simpler.
