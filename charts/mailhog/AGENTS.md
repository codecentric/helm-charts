# AGENTS.md — mailhog Chart

MailHog, an e-mail (SMTP) testing tool for developers. Chart version 5.8.0, appVersion `v1.0.1` (image tag defaults to appVersion since `values.yaml` sets `tag: ""`). Small, simple chart — Deployment-based, no subchart dependencies, no schema file. **Excluded from chart-testing** (root `ct.yaml` `excluded-charts`), so CI does not lint/install it; changes here won't be caught automatically and need manual verification.

## Template Inventory (`templates/`)

| File | Resource | Notes |
|---|---|---|
| `deployment.yaml` | Deployment | Single container, `MH_HOSTNAME` env auto-set from pod name (unless user sets it in `extraEnv` — deduped by collecting names first). |
| `service.yaml` | Service | Two ports: http (8025, Web UI) and smtp (1025). `namedTargetPort: true` default; set `false` to use integer target ports (GCE health checks don't support named target ports). |
| `ingress.yaml` | Ingress | API-version negotiation at render time: `networking.k8s.io/v1` on K8s ≥1.19, else `v1beta1`, else `extensions/v1beta1`. |
| `auth-secret.yaml` | Secret `<fullname>-auth` | When `auth.enabled` and no `existingSecret`; contents `b64enc`'d into file `auth.fileName`. |
| `smtp-secret.yaml` | Secret `<fullname>-outgoing-smtp` | When `outgoingSMTP.enabled` and no `existingSecret`; JSON-encoded (`toJson` then `b64enc`). |
| `serviceaccount.yaml` | ServiceAccount | `automountServiceAccountToken: false` by default (no API access needed). |

## Helpers (`_helpers.tpl`)

Standard set (`mailhog.name`, `mailhog.fullname` with 63-char truncation, `mailhog.labels`/`selectorLabels`, `mailhog.serviceAccountName`) plus `mailhog.authFileSecret` / `mailhog.outgoingSMTPSecret` (existingSecret name or `<fullname>-auth` / `<fullname>-outgoing-smtp`).

## Design Notes

- **No `tpl` pattern here** — unlike the keycloak charts, values are plain structures rendered with `toYaml`; `extraEnv`/`extraContainers`/`affinity` are native YAML lists/maps, not strings.
- Probes are `tcpSocket` against the SMTP container port, always rendered; `livenessProbe`/`readinessProbe` values merge extra fields (readiness merges only if non-empty).
- Auth and outgoing-SMTP config are mounted as volumes from the Secrets (`/authdir`, `/config`), wired into `MH_AUTH_FILE` / `MH_OUTGOING_SMTP` env vars.
- Hardened defaults: `readOnlyRootFilesystem`, all capabilities dropped, runAsNonRoot uid/gid 1000, no privileged, no SA token automount.
- **Quirk**: in `outgoingSMTP.fileContents`, the `port` of each server **must be a string** (Go MailHog config requirement) — noted in values.yaml comments.

## Verification (manual — chart is ct-excluded)

```bash
helm lint charts/mailhog
helm template t charts/mailhog -f charts/mailhog/ci/ingress-values.yaml
# exercise toggles:
helm template t charts/mailhog --set auth.enabled=true,auth.fileContents=user:pass \
  --set outgoingSMTP.enabled=true,service.type=NodePort,service.nodePort.http=30080,service.nodePort.smtp=30025,ingress.enabled=true
```

## Rules

- Any change requires a `version` bump in `Chart.yaml` and a DCO-signed commit.
- Docs: new/changed values go into the README parameter table; behavior changes into `NOTES.txt`.
