---
title: Configuration and process lifecycle
summary: Layered YAML with fatal-on-unset ${VAR} placeholders is parsed once at startup, and run() error owns the whole lifecycle with errgroup as process supervisor.
keywords: [config, YAML, placeholder, ${VAR}, defaults, validation, secrets, startup, shutdown, run() error, errgroup, signal.NotifyContext, drain, WriteTimeout]
related:
  - webapp/system-shape.md
  - webapp/security-secrets.md
  - webapp/performance.md
  - webapp/testing-unit-fakes.md
---

# Configuration and process lifecycle

## Parsing layered YAML configuration

```go
cfg, err := configx.ParseAndValidate[config.Config]("config.yml,secrets.yml")
```

1. Split the comma-separated file list; later files override earlier (deep
   merge) — `config.yml` holds the committed defaults, an optional overlay
   holds environment specifics.
2. In each file's **raw text**, resolve `${VAR}` placeholders from the
   environment. **An unset placeholder is fatal**, not an empty string —
   `${VAR:-default}` is the explicit opt-out.
3. Apply defaults: every config struct may implement `Default()`; defaults run
   before unmarshal so YAML always wins.
4. Validate with struct tags (`validate:"required,oneof=dev prod"`); parsing
   fails loudly on the first invalid field.

## Avoiding the configuration sharp edges

- Placeholders resolve in raw text, so one inside a YAML *comment* resolves too.
- Quote every placeholder (`'${DB_PASSWORD}'`) or a JSON-shaped credential
  parses as a YAML mapping.
- The committed dev config must contain **no** placeholders — assert it with a
  test that parses the committed file (this test also guarantees `serve` works
  on a fresh clone).
- **The config is never logged**, in full or in part: it holds credentials, and
  a service that prints its configuration at startup puts them in the log
  aggregator. Additionally expose `cfg.Secrets() []string` — the list of secret
  values — and feed it to a response-redaction middleware
  (`webapp/security-secrets.md`).

## Structuring main() as run() error

`main()` calls `run() error`; `run` is the whole lifecycle:

```go
func run() error {
    ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
    defer stop()

    cfg, err := config.Parse(*configPath)
    if err != nil { return err }
    logger := logx.MustNew(cfg.Server.LogLevel)

    db, err := pgx.NewDB(cfg.Postgres)      // + PingContext; defer Close
    if err != nil { return err }

    eg, ctx := errgroup.WithContext(ctx)
    txFactory := pgx.NewTxFactory(db)

    // Per domain, bottom-up: infra → service → handlers.
    userPersistence := userinfra.NewPostgresPersistence(db, logger)
    userService := userservice.NewService(cfg.User, userPersistence, txFactory, logger)
    userHandlers := usertransport.NewHandlers(userService, logger)

    // Cross-domain wiring, then the wiring gate:
    userService.SetWelcomeNotifier(notificationService)
    if err := userService.ValidateWiring(); err != nil { return err }

    handler := httpx.Recover(httpx.SecureHeaders(buildRouter(userHandlers /*...*/)))
    server := &http.Server{
        Addr: cfg.Server.Address, Handler: handler,
        // ReadTimeout stays 0: it bounds the ENTIRE body and would kill slow
        // uploads. Slowloris is ReadHeaderTimeout's job; upload routes set
        // their own body deadlines (webapp/performance.md).
        ReadHeaderTimeout: 15 * time.Second,
        WriteTimeout:      75 * time.Second, // ≥ longest route carve-out
        IdleTimeout:       60 * time.Second,
    }

    eg.Go(func() error { return userService.Run(ctx) }) // background workers
    eg.Go(func() error {
        if err := server.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
            return err // ErrServerClosed is the normal shutdown signal, not a failure
        }
        return nil
    })
    eg.Go(func() error {
        <-ctx.Done()
        // WithoutCancel: the parent is already cancelled; the drain needs its own deadline.
        sctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 75*time.Second)
        defer cancel()
        return server.Shutdown(sctx)
    })

    if err := eg.Wait(); err != nil && !errors.Is(err, context.Canceled) {
        return err
    }
    return nil
}
```

## Supervising goroutines and draining on shutdown

Rules baked into that shape:

- `signal.NotifyContext` is the root context; **errgroup is the process
  supervisor** — every long-lived goroutine belongs to it, and workers return
  `nil` on cancellation so a normal SIGTERM is not an error.
- The **drain window equals `WriteTimeout`** — a shorter drain drops exactly
  the requests your slow-route carve-outs promised to allow.
- Metrics are a **separate listener** (`:9090`) with no public route
  (`webapp/security-http-hardening.md`).
