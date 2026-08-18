---
title: Entity layer — invariants, value objects, sentinel errors
summary: The entity layer holds validating value objects, invariant-checking constructors and mutators, actor-based operations, and one sentinel-error block per file.
keywords: [entity, value object, invariant, constructor, mutator, validation, comparable, redaction, sentinel error, actor, permission]
related:
  - webapp/backend-layers.md
  - webapp/backend-services.md
  - webapp/backend-errors.md
  - webapp/security-authorization.md
---

# Entity layer — invariants, value objects, sentinel errors

The entity layer contains entity types, value objects, sentinel errors, and
pure state-transition methods. No I/O, no SQL, no HTTP vocabulary — name things
in domain terms (`OrderPlaced`, not `WebhookPayload`).

## Defining value objects

Every primitive that has rules gets a type with a validating constructor:

```go
type Email string

func EmailFromString(s string) (Email, error) {
    email := Email(s)
    if err := email.Validate(); err != nil {
        return Email(""), err
    }
    return email, nil
}

func (e Email) String() string { return string(e) }

func (e Email) Validate() error {
    var errs []string
    if e != "" && !emailRe.MatchString(string(e)) {
        errs = append(errs, "invalid email format")
    }
    return NewValidationError(errs) // returns nil for an empty slice
}
```

Two sub-rules that pay off later:

- **Value objects stay `comparable`** (no pointer/slice fields), so they can be
  map keys. If a role is a pair (base role + specialisation), make it a struct
  of two strings, not a formatted string.
- **Secrets redact themselves.** A `Password` type's `String()` returns
  `"**REDACTED**"` so it is safe to pass to any logger; the real bytes are
  behind an explicit `Inner()`.

## Enforcing invariants in constructors and mutators

The entity is never in an invalid state because the only ways to create or
change it check the rules:

```go
func NewUser(email Email, password Password) (User, error) {
    if err := email.Validate(); err != nil {
        return User{}, err
    }
    if err := password.Validate(); err != nil {
        return User{}, err
    }
    hash, err := password.Hash()
    if err != nil {
        return User{}, err
    }
    return User{ID: NewUserID(), Email: email, PasswordHash: hash, Role: RoleUser}, nil
}

func (u *User) VerifyEmail() error {
    if u.EmailVerified {
        return ErrEmailAlreadyVerified
    }
    u.EmailVerified = true
    u.UpdatedAt = time.Now()
    return nil
}
```

## Deciding actor-based operations in the entity

When an operation's legality depends on who performs it, the entity method
takes the actor and decides — the service just calls it:

```go
func (u *User) AdminDeactivate(actor *User) error {
    if err := actor.CheckPerm(PermUserDeactivate); err != nil {
        return err
    }
    if u.Role == RoleAdmin {
        return ErrCannotDeactivateAdmin
    }
    if !u.IsActivated {
        return ErrUserNotActive
    }
    u.IsActivated = false
    u.ClearAssignments()
    return nil
}
```

This is what "invariant entities" means in practice: business rules are methods
on the data they protect, testable without a database, impossible to bypass
from a handler.

## Declaring sentinel errors

One `var (...)` block per entity file. Each sentinel carries a **generic
user-facing message** plus internal detail attached separately
(`webapp/backend-errors.md`):

```go
var (
    ErrWrongPassword         = NewUnauthorizedError("wrong email or password").WithDebug("wrong password")
    ErrCannotDeactivateAdmin = NewForbiddenError("forbidden").WithDebug("cannot deactivate admin")
    ErrRecoveryCodeExpired   = NewBadRequestError("recovery code expired").
                                   WithReason("recovery_code_expired") // machine-readable, for client i18n
)
```
