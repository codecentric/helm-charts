# AGENTS.md — keycloak Chart (legacy WildFly)

> **This chart is frozen.** It deploys the old WildFly-based Keycloak distribution (`appVersion: 17.0.1-legacy`) and is explicitly marked "no longer maintained" in its README. It is **excluded from chart-testing** (see root `ct.yaml` `excluded-charts`), so CI will not lint or install it. Do not modify unless explicitly asked; for any Keycloak work use `charts/keycloakx`. If a bugfix is genuinely required here, it still needs a manual version bump and a DCO sign-off.

## Architecture

- Chart version 18.10.0. Deployed as a StatefulSet with a headless discovery service (same overall shape as keycloakx, but WildFly semantics).
- **Has a subchart dependency**: `postgresql` 10.16.2 from the bitnami archive-full-index repo (`condition: postgresql.enabled`, **enabled by default**). `Chart.lock` pins digest `sha256:18d778…`. Requires `helm dependency build` (or `helm dependency update`) before lint/template works — vendored `charts/` subdir is git-ignored via root `.gitignore` (`charts/**/charts`).

## Key Differences vs. keycloakx

| Aspect | keycloak (this) | keycloakx |
|---|---|---|
| Runtime | WildFly, `/auth` fixed, ports 8080/8443/9990 (management) | Quarkus, configurable relative path, management port 9000 |
| Env vars | `DB_VENDOR`, `DB_ADDR`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `JGROUPS_*`, `KEYCLOAK_USER(_FILE)` | `KC_*` vars |
| DB | Optional bundled PostgreSQL subchart + `pgchecker` init container | No subchart; `database.*` values → external DB + `dbchecker` |
| Startup scripts | `startupScripts` (map) → ConfigMap mounted at `/opt/jboss/startup-scripts/`, incl. `scripts/keycloak.cli` (WildFly CLI setting `node-identifier`) | Only when user sets `startupScripts` (no default scripts) |
| fullname truncation | **20 chars** (WildFly `node-identifier` is limited to 23, leaves room for `-N` pod suffix) | 63 chars |
| HPA apiVersion | v2beta2 vs v2 selected at render time | autoscaling/v2 only |
| Ingress | networking.k8s.io/v1 (+ beta fallback logic) | v1 only |
| No `namespaceOverride` | Resources use `.Release.Namespace` directly | `keycloak.namespace` helper everywhere |
| `serviceMonitor.port` | `http-management` (9990) | `http-internal` (9000) |

Shared heritage: the string-`tpl` values pattern (`extraEnv`, probes, `affinity`, labels/annotations via `printf "%s: %s" $key (tpl $value $ | quote)`), checksum annotations on the pod template, `secrets` map → arbitrary Secrets, `keycloak.postgresql.fullname` helper for the subchart naming, and the same test-hook approach (selenium/phantomjs pod needing `<fullname>-admin-creds` with `user`/`password`).

## CI Values (`ci/`)

Excluded from `ct`, but kept for manual runs:

- `h2-and-ingress-values.yaml` — H2 DB (`DB_VENDOR: h2`), admin creds via `KEYCLOAK_USER_FILE`/`KEYCLOAK_PASSWORD_FILE` from a chart-created secret, ingress + console ingress with test labels/annotations, `test.enabled: true`.
- `postgres-ha-values.yaml` — 2 replicas, bundled PostgreSQL with persistence, DNS_PING jgroups discovery via `keycloak.serviceDnsName`, `CACHE_OWNERS_COUNT=2`, custom startup script, lifecycle hook.

## Working on It (if ever needed)

```bash
helm dependency build charts/keycloak   # pulls postgresql 10.16.2 into charts/keycloak/charts/
helm lint charts/keycloak
helm template t charts/keycloak -f charts/keycloak/ci/postgres-ha-values.yaml
```

Do not commit the downloaded `charts/keycloak/charts/` subdirectory. Any change requires a `version` bump in `Chart.yaml` and a DCO-signed commit. Approvers/reviewers: see the chart's `OWNERS` file.
