---
title: Rendering service config into a deployment
summary: Why the config block is copied verbatim as a literal scalar, and which values the template — not the process — substitutes.
theme: devops
keywords: [chart, values, configmap, literal block scalar, toYaml, verbatim, quoting, template token, image tag, subchart host, mount path, placeholder collision]
related:
  - backend/configuration-loading.md
  - devops/secrets-and-delegation.md
  - devops/release-tagging-and-gitops.md
---

## The deployed config is a chart value

Each service's config file is a value in its deployment chart, rendered by a config-map template and mounted into the pod at a fixed path.

## It is copied verbatim, not re-serialised

The value is a **literal block scalar**, passed through unchanged. It is deliberately **not** run through a YAML re-serialisation helper.

Two reasons, and both have bitten:

1. **Re-serialising a mapping drops the quoting.** The process substitutes environment placeholders into the raw file before parsing, and a JSON credential in an unquoted placeholder then parses as a mapping instead of a string — a boot failure. The quoting the config author wrote is load-bearing, so it must survive rendering.
2. **Verbatim means the comments reach the pod.** The file an operator reads in the cluster is the file that was reviewed in the merge request.

## Two substitution mechanisms that must not be confused

| Marker | Substituted by | Used for |
| --- | --- | --- |
| `${VAR}` | The **process**, at boot, from its environment | Secrets delivered by the secrets operator |
| `@@TOKEN@@` | The **chart template**, at render time | Values only the template can know |

The template-side markers are delimited so they are **visibly not YAML** and cannot be mistaken for something the process resolves. What they carry:

- The deployed image tag — CI bumps one field, and a second copy inside the config would be a second place to forget.
- A subchart's service host, which is named after the release.
- The volume mount path.

## Consequences for a change

- Adding a secret is a placeholder in the config value plus a key in the secret map. Nothing secret is ever written into the chart.
- Adding a value the template must compute means a new template token, not a new environment variable — an environment variable the chart sets and nothing reads looks exactly like one that works.
- Changing the mount path is a template concern, not a config concern.

## Reference shape

The fullest example in the tree pairs a config package, a committed development config, a chart values block and the config-map template. Its provider list is worth copying as a shape: one entry per backend, each with an id, a type, an explicit allow-list of operations, and the credential itself rather than the name of a variable holding it.
