# keycloakx issue triage guide

## 1. Classify the issue

| Class | Signals | Expected outcome |
|---|---|---|
| **Chart bug — rendering** | `helm template`/`install` error, wrong/missing field in rendered YAML, schema rejects valid values | Reproduce with `repro.sh template`; fix in `templates/` or `values.schema.json` |
| **Chart bug — runtime** | Renders fine, but pods crash / never ready / wrong `KC_*` env / probes hit wrong path | Reproduce with `repro.sh install`; inspect diagnostics |
| **Upgrade regression** | "worked in X, broken after upgrading to Y" | `repro.sh install --version X` then `repro.sh upgrade --version Y` with the same values |
| **Feature request** | "please add / support …" | Nothing to reproduce; confirm it is missing on master, propose design |
| **Upstream Keycloak problem** | Error comes from Keycloak itself, chart output is correct | Not a chart bug; point to keycloak/keycloak issue tracker / docs |
| **Misconfiguration / support question** | Values contradict docs (e.g. `extraEnv` as list instead of string), missing `--hostname`, wrong DB settings; Terraform `set` blocks with `type = "string"` / `set_string` passing booleans as strings -> schema rejects (`Invalid type. Expected: boolean, given: string`) | Not a bug; propose the correct values (and maybe a docs improvement) |
| **Already fixed** | Reproduces on reporter's version, NOT on `origin/master` | Find the fixing commit (`git log -S`/`git bisect`), say which release contains it |
| **Duplicate** | Same symptom in another issue/PR (`issue-context.sh` related list) | Reference the original; existing open PR may already fix it |
| **Environment-specific** | Only on OpenShift / service mesh / specific CNI / Ingress controller | Reproduce the chart-side part (rendered manifests); state what cannot be reproduced on k3d |

## 2. Where keycloakx bugs usually live

- **Conditional guards** — a resource rendering although its feature is disabled
  (or vice versa). Look for `{{- if }}` blocks that only guard part of a file, e.g.
  a second document (`---`) after the first `end`.
- **Multi-document separators** — a `---` outside every `if`/`range` guard renders as a
  lone empty document when all sections are disabled. Harmless for `helm template` and
  current Helm lint (≥3.5 skips empty docs, name check is warning-only) — but tooling
  with older Helm libraries treats it as an object with `metadata.name: ""` and ERRORS
  (e.g. terraform-provider-helm ≤ v2.0.x: issue #922). Correct pattern: put the
  separator INSIDE the guard of the second document, like `ingress.yaml` lines 52-53
  (`{{- if $ingress.console.enabled }}` followed by `---`). Audit with
  `grep -n '^---' charts/keycloakx/templates/*.yaml` and check each separator's guard.
- **String-`tpl` values** — `extraEnv`, `affinity`, probes, … must be YAML
  *strings*. Users passing native maps/lists → schema error (misconfiguration, but
  maybe a docs issue).
- **Schema drift** — `values.schema.json` missing a key that `values.yaml` /
  templates support, wrong `type`, or `additionalProperties: false` too strict.
- **Helpers** — `keycloak.fullname` truncation, `keycloak.namespace` not used
  (umbrella charts / `namespaceOverride`), labels/selector helpers.
- **Path handling** — `http.relativePath` / `http.managementRelativePath`
  trailing slashes in probes, ingress paths, NOTES.
- **Env mapping** — `database.*`, `proxy.*`, `cache.*` → `KC_*` env vars in
  `statefulset.yaml`.
- **API versions** — `capabilities`/`semverCompare` branches (PDB, Gateway API,
  ServiceMonitor).
- **NOTES.txt** — branches per exposure mode can fail on unusual value combos.

## 3. Tool fingerprints — who actually produced the error

Chart consumers are not always the `helm` CLI: **terraform-provider-helm** runs Helm's
lint library inline during `plan`/`apply`, and GitOps tools (ArgoCD, Flux) render with
their own pinned Helm versions. An error that won't reproduce with your local `helm`
may still be real for that tool's embedded Helm library — vary the reproduction, don't
conclude "not reproducible" from the CLI result alone.

| Signature in the report | Producer | Reproduce with |
|---|---|---|
| `malformed chart or values:` | terraform-provider-helm (`helm_release` with `lint = true`) — `lintChart()`/`resultToError()` in `helm/resource_helm_release.go` (v2.x: `helm/resource_release.go`) | `repro.sh tf-lint --tf-provider <P>`; provider <= v2.0.x embeds helm lib v3.3.4 (invalid metadata name = ERROR), v2.1+ embeds >= v3.5.3 (warning only) |
| `Error: UPGRADE FAILED: another operation (install/upgrade/rollback) is in progress` | Helm CLI, stuck release state | not a chart bug: `helm rollback`, clear pending hooks |
| `error validating data` / `no matches for kind` | cluster-side validation / missing CRDs | install CRDs (Gateway API, ServiceMonitor, ...) or template with `--api-versions` |
| error only inside ArgoCD/Flux UI | their pinned Helm version's rendering | `mise exec helm@<that version> -- helm template ...`; check their release notes for the Helm version |

Method to attribute an unknown error string ("tool fingerprinting"):

1. `gh search code '"<exact unique phrase>"'` to find the source repository and file.
2. Read the code at the reporter's tool version:
   `gh api "repos/OWNER/REPO/contents/<path>?ref=<tag>" -q .content | base64 -d`.
3. If unsure which version behaves how, fetch the same file across several tags and
   diff ("version archaeology") — that is how #922 was traced to helm 3.3/3.4 treating
   `validateMetadataName` as an error while >=3.5 downgraded it to a warning
   (refs helm/helm#8596).

## 4. Reproduction tips

- Always test **both** the reporter's chart version (`--version X.Y.Z`) and
  `origin/master` (`--ref origin/master`). That single comparison distinguishes
  "valid & open" from "already fixed".
- Reduce the reporter's values to the **minimal** set that still triggers the
  problem; that minimal file becomes the regression test values for the PR
  (and possibly a new `charts/keycloakx/ci/*-values.yaml`).
- Rendering bugs: a live install is unnecessary — `repro.sh template` is
  conclusive. Use `helm template --show-only templates/<file>.yaml` (via
  `-o` + reading the file) to focus on one resource.
- Runtime bugs needing a DB: `--with-postgres`. Needing Ingress: k3d ships Traefik.
- Clustering (`--set replicas=2`): the chart's default `affinity` has a
  **required** pod anti-affinity per hostname, so on a single-node k3d cluster
  replica 2 stays `Pending` (`FailedScheduling ... didn't match pod anti-affinity`).
  That is environment, not a bug. Unless the issue is about affinity, add
  `--set affinity=""` (or soft anti-affinity values) and mention it in the report.
- Gateway API / ServiceMonitor / Route CRDs are usually NOT installed on k3d —
  for those, rely on `helm template` (with `--api-versions` via a values tweak
  if the template checks `.Capabilities`), and say so in the report.
- Image pull failures, OOM on the local machine, missing CRDs → environment,
  not chart. Never report those as "reproduced".

## 5. Fix proposal checklist

- Smallest change that fixes the root cause; no drive-by refactors.
- Backwards compatible for users who don't hit the bug: defaults render the
  same (verify with the keycloakx-pr-review `render-diff.sh`).
- `Chart.yaml` `version` UNCHANGED: version bumping and releasing is a maintainer
  task — flag the intended bump level (patch/minor/major) in the report so the
  maintainer applies it when cutting the release.
- New/changed values: `values.yaml` + `values.schema.json` + README parameter
  table (+ `NOTES.txt` if post-install behavior changes).
- Regression coverage when it makes sense: a `ci/*-values.yaml` scenario
  (CI installs every file in `ci/`), keep it installable on kind.
- PR must be signed off (`git commit -s`) — mention it, don't do it.
