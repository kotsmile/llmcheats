---
title: Configuration — one YAML file, no direct environment reads
summary: The single-config-file rule, the placeholder substitution traps that have caused boot failures, and why struct env tags do nothing.
theme: backend
keywords: [config file, ParseAndValidate, Defaulter, validate tag, env tag, placeholder, "${VAR}", substitution, fatal on unset, quoting, dev config, os.Getenv]
related:
  - devops/service-config-in-charts.md
  - devops/secrets-and-delegation.md
  - backend/layered-architecture.md
---

## The rule

Every backend service is configured by **one YAML file and nothing else**. A service reads a config path flag and never reads the environment directly for a setting of its own.

This is a rule, not a default. The alternative was a dozen environment reads scattered across the entry points: no single place answered "what is this deployment configured to do", and a variable the deployment set but nothing read looked exactly like one that worked.

```go
cfg, err := config.ParseAndValidate(configPath)
```

Shape a new service like the others: a `config` package next to the entry point, `yaml` + `validate` tags, `Default()` methods for everything with a sensible value, and a committed dev config file at the project root.

## Precedence

Lowest to highest:

1. `Default()` methods on config structs, via a defaulter interface.
2. YAML files merged in the order given on the command line.

Validation via `validate` tags runs **after both stages apply**.

## Struct `env` tags are dead

The config parser never reflects over `env` tags — adding one changes nothing. Any surviving tag is vestigial.

**The environment reaches the config through `${VAR}` placeholders inside the YAML.** The loader substitutes them in the raw file before unmarshalling. A new secret is a placeholder in the config file, never a tag.

## Four substitution traps

1. **Substitution runs on the RAW FILE, before the YAML is parsed.** A placeholder inside a *comment* is resolved too, and an unset one there fails the boot exactly as a real value would.

2. **An unset placeholder is fatal**, not an empty string. That is the right direction: an empty session key or an empty service-account key boots a process that looks healthy and fails at the first request.

   The one opt-out is `${VAR:-default}` — shell syntax — for a value whose *absence* has a defined meaning rather than being a mistake. Today there is exactly one: an optional admin password where empty means "that sign-in door is off". Spelling the default out writes the decision down; everything without one still refuses to boot.

3. **Quote every placeholder** — `token: '${API_TOKEN}'`. The substituted text becomes YAML, so a JSON service-account key in an unquoted placeholder parses as a *mapping*, not a string, and the process dies at boot with an unmarshal error. Single quotes survive the `"` and `\n` a JSON credential is full of.

4. **A dev config file must contain no placeholders at all**, or running the service locally needs a shell full of exports. Each service's config package has a test asserting this.

## How secrets get in

```
the secrets operator writes values into a platform Secret
  → the pod imports them as environment variables
    → the process resolves them into its config file
```

A credential is declared next to the thing that needs it, and nothing secret is written into a deployment manifest.

## Third-party client configs

Each shared-library client package defines its own `Config` struct alongside the client. Do not add third-party service configs to the central config struct.

## Adding an environment-backed value

The change is not one file. Update, in the same commit:

1. The local dev environment file (gitignored, real values).
2. The committed template with empty values.
3. The config file mapping the placeholder to a YAML key.
4. The end-to-end test config with a stub value.
5. The deployment values for each environment.

Naming: `SERVICENAME_VARIABLE`, full service name, no abbreviations.
