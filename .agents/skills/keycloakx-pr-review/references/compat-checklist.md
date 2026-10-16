# Backwards-compatibility checklist for keycloakx PRs

Detailed reference for interpreting the SKILL.md workflow steps. Distilled from the
chart's AGENTS.md, its git history and past regressions. Not every item applies to
every PR — the render-diff and live test are the primary evidence; this checklist
tells you what a diff hunk *means*.

## Severity ladder

| Severity | Meaning | Consequence for verdict |
|---|---|---|
| BLOCKER | Breaks (or plausibly breaks) users upgrading an existing installation | NOT good to go |
| SHOULD-FIX | Violation of repo rules / docs contract, or risky but intentional change | good to go, with fixes recommended |
| NOTE | Expected, informational | none |

## 1. Versioning (repo rules — all enforced by convention, not tooling)

- `version` in `Chart.yaml` MUST be bumped on every chart change.
  - fix → patch; new opt-in feature → minor; breaking (defaults changed, values
    renamed/removed, new required values, template output changed for unchanged
    values) → major (semver) — the repo has used minor for these historically,
    so at minimum flag the mismatch in the review.
- If Keycloak is upgraded, BOTH `Chart.yaml appVersion` AND `values.yaml image.tag`
  must change — values.yaml pins the tag explicitly, `appVersion` alone changes nothing.

## 2. values.yaml — defaults and value surface

The rendered-manifest noise floor is the set of lines that MAY change with every
version bump, everything beyond it needs justification:

```diff
-    helm.sh/chart: keycloakx-7.3.1
+    helm.sh/chart: keycloakx-7.4.0
-    app.kubernetes.io/version: "26.7.3"
+    app.kubernetes.io/version: "26.8.1"
-          image: "quay.io/keycloak/keycloak:26.7.3"
+          image: "quay.io/keycloak/keycloak:26.8.1"
```

`checksum/config-startup`, `checksum/secrets` annotation changes are expected when
the hashed content changes — but understand WHY the content changed (it includes
labels, so version bumps change it legitimately).

Beyond that noise:

- A changed default in `values.yaml` affects every user who did not set that key.
  Render-diff shows it in the `defaults` profile. BLOCKER unless intentional +
  version bump + documented + (ideally) flagged as migration note in README.
- Removed/renamed keys break existing values files with no error at upgrade time —
  the setting just silently stops working. BLOCKER. (Distinguish: keys that are
  merely NEW are fine.)
- The string-`tpl` pattern: `extraEnv`, `extraEnvFrom`, `extraContainers`,
  `extraInitContainers`, `extraVolumes`, `extraVolumeMounts`,
  `volumeClaimTemplates`, `affinity`, `lifecycleHooks`, `topologySpreadConstraints`,
  all probes, and all `*.labels`/`*.annotations` maps must be YAML strings (values
  are `tpl`'d, keys are not). Changing `values.schema.json` typing for such a value
  from `string` to a structural type (or vice versa) rejects existing values.
- New required keys without defaults = BLOCKER (the live test catches this: upgrade
  with unchanged values fails).

## 3. values.schema.json

- New `required` entries, removed properties, narrowed types, new
  `additionalProperties: false` — all reject previously valid values → BLOCKER.
- Watch the historical trap from #925: top-level keys only validate if listed in
  `properties`; a PR adding a top-level value without a schema entry is a SHOULD-FIX.
- Pull requests tightening the schema (e.g. `httpRoute.servicePort` → integer,
  `httpRoute.rules[].additionalProperties: false`) were intentional — the skill's
  render profiles use only documented values, so schema regressions of NEW features
  won't show in render-diff; check the schema diff separately.

## 4. Kubernetes immutability and upgrade blockers

Changes that make `helm upgrade` FAIL on existing installs:

- `spec.selector` (StatefulSet) — labels there are immutable. The chart builds it
  from `keycloak.selectorLabels` — any change to name/instance/name-version keys is
  a BLOCKER. (The live test surfaces this as an upgrade error.)
- Renamed container ports referenced by name elsewhere (`http`, `https`,
  `http-internal` are used by Services, networkPolicy, serviceMonitor, probes,
  httproute) — rolling updates fail or silently mis-target.
- Renamed resources (Service `<fullname>-http`, `<fullname>-headless`, Secret
  `<fullname>-database`, ConfigMap `<fullname>-startup`): `helm upgrade` then
  ORPHANS the old resource and creates a new one — for the headless Service this
  breaks jgroups discovery; for the Database Secret it changes password sourcing.
  Any diff hunk that changes a `name:` of a pre-existing resource needs scrutiny.

## 5. Behavioral mappings (users depend on the generated env)

The chart maps values to `KC_*` env vars; changes to them change Keycloak runtime
behavior without any user action (show up in the `defaults` render-diff as changed
env lines — real PRs did this, e.g. the 26.1 `cache.stack: default` mapping change
from `ispn` to `jdbc-ping`):

- `database.*` → `KC_DB*`; `proxy.*` → `KC_PROXY_HEADERS`/`KC_HTTP_ENABLED`;
  `http.relativePath`/`managementRelativePath` → `KC_HTTP_*_RELATIVE_PATH`;
  `cache.stack` → `KC_CACHE`/`KC_CACHE_STACK`.
- A new env var for a value that previously required the user to set it manually is
  fine (opt-in); a changed mapping needs a deliberate migration note.
- Probes only render when `health.enabled`/`metrics.enabled` — a PR making probes
  unconditional (or conditional) changes every user's pod spec.

## 6. Docs contract (repo rules — SHOULD-FIX, mechanical)

- Every new/changed value must appear in the README parameter table.
- Post-install behavior changes → `NOTES.txt` (NOTES.txt is not rendered by
  `helm template` — review it via `git diff` on the file itself).
- New `tpl`'d values belong in the README `tpl` section.
- New user-facing features should get CI values coverage (`ci/h2-values.yaml`) if
  reasonable.

## 7. Interpreting live-test failures

| Symptom | Usually means |
|---|---|
| `Error: field is immutable` | selector/label change — BLOCKER |
| upgrade fails, schema/`values.schema.json` error | regression (BLOCKER) |
| CrashLoopBackOff, exit 1 keycloak | functional regression — read `kubectl logs` |
| Rollout stuck, pod restarting but never Ready | probe path/port mismatch (see §4) |
| ImagePullBackOff | environment (registry access) — not the PR; re-check `image.tag` exists on quay.io before blaming it |
| Everything green, only `helm.sh/chart` revision changed | pure values/README/CI PR — no compat risk |

## 8. Things that are intentionally NOT expensed by the scripts

- `extraManifests`, `startupScripts`, `secrets` user content — unbounded inputs; the
  kitchen-sink profile covers representative shapes.
- Gateway API CRD presence (listenerSet/httpRoute render fine without the CRDs;
  installing them into k3d is out of scope for the live test).
- Multi-replica Infinispan caching (dev-file H2 cannot back `jdbc-ping` across
  pods) — the live test runs single-replica deliberately; render-diff covers the
  config surface.
