# AGENTS.md — keycloakx Chart

Quarkus-based Keycloak (Keycloak-X), tracking the current Keycloak release (`appVersion` in `Chart.yaml`). **This is the active, primary chart of the repository** — nearly all feature work happens here. Deployed as a StatefulSet. Fully self-contained: no subchart dependencies (the bitnami repo referenced in root `ct.yaml` is only used by `examples/`, which are excluded from the package via `.helmignore`).

## Template Inventory (`templates/`)

| File | Resource | Notes |
|---|---|---|
| `statefulset.yaml` | StatefulSet | The core workload. Builds `KC_*` env vars from values, init containers, probes, volumes. |
| `service-http.yaml` | Service `<fullname>-http` | Exposes http (8080), https (8443), and management (9000, port name from `http.internalPort`). |
| `service-headless.yaml` | headless Service | For DNS-based cluster discovery (jgroups). Referenced by `keycloak.serviceDnsName`. |
| `ingress.yaml` | Ingress (+ optional `-console` ingress) | networking.k8s.io/v1, per-path backend overrides for ALB-style annotations. |
| `httproute.yaml` | Gateway API HTTPRoute (+ optional console route) | When `listenerSet.enabled`, parentRefs/hostnames are auto-derived from the ListenerSet. |
| `listenerset.yaml` | Gateway API ListenerSet | Experimental (v1); namespace-level listener config without Gateway write access. |
| `route.yaml` | OpenShift Route | Edge/passthrough/reencrypt TLS. |
| `networkpolicy.yaml` | NetworkPolicy | Ingress (8080/8443/extraPorts) and optional egress rules. |
| `hpa.yaml` | HPA (autoscaling/v2) | When enabled, `replicas` is omitted from the StatefulSet so the HPA owns it. |
| `poddisruptionbudget.yaml` | PDB | `policy/v1` vs `v1beta1` chosen via `semverCompare`. Created if the `podDisruptionBudget` value has **any** key set. |
| `servicemonitor.yaml` | ServiceMonitor ×2 | Loops over a dict of `serviceMonitor` + `extraServiceMonitor` (for the Keycloak Metrics SPI) in one template. |
| `prometheusrule.yaml` | PrometheusRule | Alert rules passed through as-is. |
| `rbac.yaml` | Role + RoleBinding | Only when `rbac.create` AND `rbac.rules` are set (e.g. KUBE_PING). |
| `serviceaccount.yaml` | ServiceAccount (+ ClusterRole for KUBE_PING) | `serviceAccount.allowReadPods` creates the `jgroups-kubeping` cluster role/binding. |
| `secrets.yaml` | arbitrary Secrets | Map under `secrets.<name-suffix>`; values passed through `tpl`. |
| `database-secret.yaml` | Secret `<fullname>-database` | Only when `database.password` is set and `database.existingSecret` is empty. |
| `configmap-startup.yaml` | ConfigMap `<fullname>-startup` | Only when `startupScripts` is set (not present in values.yaml by default). |
| `extra-manifests.yaml` | arbitrary | Each `extraManifests` entry rendered via the `keycloak.render` helper (strings are `tpl`'d; objects are `toYaml`'d then `tpl`'d). |
| `test/pod-test.yaml`, `test/configmap-test.yaml` | helm test hooks | Selenium-based smoke test. Requires a Secret `<fullname>-admin-creds` with keys `user`/`password` (see `ci/h2-values.yaml`). |
| `NOTES.txt` | — | Branches per exposure mode: ListenerSet → HTTPRoute → Ingress → NodePort → LoadBalancer → ClusterIP port-forward. |

## Helper Templates (`_helpers.tpl`)

- `keycloak.name` / `keycloak.fullname` / `keycloak.chart` — standard naming (63-char truncation).
- `keycloak.labels` / `keycloak.selectorLabels` — `app.kubernetes.io/version` derived from `image.tag` **or** `Chart.AppVersion`, plus `commonLabels` (values `tpl`'d).
- `keycloak.namespace` — `namespaceOverride` → `.Release.Namespace`. **Every namespaced resource must use this helper**, not `.Release.Namespace` directly (needed for umbrella-chart deployments).
- `keycloak.serviceAccountName` — generated from fullname unless overridden.
- `keycloak.serviceDnsName` — `<fullname>-headless.<ns>.svc.<clusterDomain>`.
- `keycloak.databasePasswordEnv` — `KC_DB_PASSWORD` from chart-managed or existing secret.
- `keycloak.render` — renders strings via `tpl`, objects via `toYaml` then `tpl` (used by `extraManifests`).

## Values Design Patterns — Critical

1. **String-`tpl` pattern**: many values (`extraEnv`, `extraEnvFrom`, `extraContainers`, `extraInitContainers`, `extraVolumes`, `extraVolumeMounts`, `volumeClaimTemplates`, `affinity`, `lifecycleHooks`, `topologySpreadConstraints`, `livenessProbe`, `readinessProbe`, `startupProbe`, and all `*.labels`/`*.annotations` maps) are rendered with `tpl`. They **must be YAML strings in values.yaml** (e.g. `affinity: |`), not native structures — `values.schema.json` enforces `"type": "string"` for these. When adding a new `tpl`'d value, add it to the schema and to the README `tpl` section.
2. **Label/annotation maps**: uniformly rendered with `printf "%s: %s" $key (tpl $value $ | quote)` — values inside maps are templated, keys are not.
3. **Defaults embed template expressions** (e.g. probe paths use `{{ tpl (coalesce .Values.http.managementRelativePath .Values.http.relativePath) $ | trimSuffix "/" }}/health/live`), so `helm template` output must be used to inspect effective defaults.

## Key Behavioral Mappings

- `cache.stack: default` → `KC_CACHE=ispn`, `KC_CACHE_STACK=jdbc-ping` (Keycloak ≥26.1 default; DB-table-based discovery). `custom` disables automatic cache config (set `KC_CACHE_CONFIG_FILE` + custom stack env yourself).
- `proxy.enabled: true` → `KC_PROXY_HEADERS=<proxy.mode>` (default `forwarded`); `proxy.http.enabled` → `KC_HTTP_ENABLED=true`.
- `http.relativePath` → `KC_HTTP_RELATIVE_PATH` (default `/auth`, trailing `/` trimmed except for `/`); `http.managementRelativePath` → `KC_HTTP_MANAGEMENT_RELATIVE_PATH` (empty = inherit relativePath).
- `database.*` → `KC_DB*` env vars, each individually optional. `database.existingSecret` (key `password` by default, override with `existingSecretKey`) takes precedence over chart-managed secret.
- `dbchecker.enabled` adds a busybox init container that blocks until `database.hostname:port` is reachable; requires both to be set (enforced with `required`). `skipInitContainers: true` removes **all** init containers (service-mesh workaround).
- Probes only render when `health.enabled` (liveness/startup) and `metrics.enabled` (readiness); they target the management port name (`http-internal`, containerPort 9000).
- Pod template carries checksum annotations (`checksum/config-startup`, `checksum/secrets`) to trigger rollouts on config change.
- StatefulSet (not Deployment) is required for headless-service DNS discovery — do not convert.

## Verification

```bash
# Fast checks
helm lint charts/keycloakx
helm template test-release charts/keycloakx -f charts/keycloakx/ci/h2-values.yaml > /dev/null

# Full lint (yamale + yamllint + helm lint against ci/ values)
ct lint --config ct.yaml --charts charts/keycloakx

# Install test (needs kind cluster per kind.yaml)
ct install --config ct.yaml --charts charts/keycloakx
```

- `ci/h2-values.yaml` is the CI install scenario: H2 dev-file DB, `--hostname-strict=false`, admin creds from a chart-created secret, `test.enabled: true`. New user-facing features should get CI values coverage.
- When exercising many features locally, template with several toggles on (`ingress.enabled`, `httpRoute.enabled`, `serviceMonitor.enabled`, `autoscaling.enabled`, `networkPolicy.enabled`, `route.enabled`, `dbchecker.enabled` + `database.*`) — templates are heavily conditional and dead branches hide breakage.

## Versioning & Release for this Chart

- **Version bumps are manual**: edit `version` in `Chart.yaml` (semver; breaking value/template changes → major/minor, fixes → patch).
- **Keycloak upgrades**: update **both** `Chart.yaml appVersion` **and** `values.yaml image.tag` — values.yaml pins the tag explicitly (do not rely on the `appVersion` default), so `appVersion` alone does NOT change the deployed image. Keep the two identical; `keycloak.labels` uses `image.tag | default .Chart.AppVersion`.
- Release is manual `workflow_dispatch` (root `.github/workflows/release-charts.yaml`): chart-releaser to GitHub Pages + `helm push` to GHCR.

## Gotchas

- `image.tag` default is **not** the chart version (README wording is historical) — it is `appVersion`, but current values.yaml pins it explicitly (see above).
- `httpRoute.servicePort` must be an **integer** (schema enforces), while `ingress.servicePort` is a port **name** string (`http`). Don't mix them up.
- `httpRoute.rules` schema uses `additionalProperties: false` — users cannot set `backendRefs`; the chart always points at `<fullname>-http`.
- `podDisruptionBudget` renders whenever the value is non-empty — setting any key creates the resource.
- New top-level values must be added to `values.schema.json` (top-level keys were recently made to actually validate in #925).
- `extraManifests` items may be strings or objects (both `tpl`'d via `keycloak.render`).
- `helm test` (selenium pod) expects `<fullname>-admin-creds` secret with `user`/`password` keys.
- Docs contract: every new/changed value goes into the README parameter table; post-install behavior changes go into `NOTES.txt`.

## Ownership

Approvers and reviewers are listed in this chart's [`OWNERS`](OWNERS) file (GitHub handles). That file is the single source of truth — when ownership changes, edit it, not this document.
