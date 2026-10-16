# AGENTS.md

Table of contents for AI agents working in this repository. Each chart has its own detailed AGENTS.md — read the one for the chart you are touching.

## Chart Directory

| Chart | AGENTS.md | Status |
|---|---|---|
| **keycloakx** | [`charts/keycloakx/AGENTS.md`](charts/keycloakx/AGENTS.md) | **Active, primary chart.** Quarkus-based Keycloak (current release) as a StatefulSet. Nearly all work happens here. |
| keycloak | [`charts/keycloak/AGENTS.md`](charts/keycloak/AGENTS.md) | **Frozen.** Legacy WildFly Keycloak (`17.0.1-legacy`); excluded from CI chart-testing. |
| mailhog | [`charts/mailhog/AGENTS.md`](charts/mailhog/AGENTS.md) | Excluded from CI chart-testing; simple MailHog dev/test tool chart. |

## Repository Overview

Monorepo of Helm charts maintained by codecentric, published to:
- Helm repo: `https://codecentric.github.io/helm-charts` (via chart-releaser, GitHub Pages)
- OCI registry: `ghcr.io/codecentric/helm-charts/<chart>`

## Repo-Wide Rules

These apply to every chart; chart-specific details live in the sub-AGENTS.md files.

### Verification & Testing

CI (`.github/workflows/lint-test.yaml`, on PR): `ct lint` + (if charts changed) a 3-node kind cluster (`kind.yaml`) and `ct install`. Local equivalents:

```bash
# Fast checks
helm lint charts/<chart>
helm template test-release charts/<chart>

# Full lint (yamale + yamllint + helm lint against values files in ci/)
ct lint --config ct.yaml --charts charts/<chart>

# Install test (needs a running kind cluster)
ct install --config ct.yaml --charts charts/<chart>
```

- `ct.yaml`: target branch `master`, chart-dirs `charts`, version-increment check disabled, **excludes `keycloak` and `mailhog`** — only keycloakx is CI-verified.
- Keep template whitespace/indentation clean: 2-space indent, trailing whitespace trimmed, final newline (`.editorconfig`); ct runs yamllint over rendered output.
- When exercising many features locally, template with feature toggles enabled (`ingress`, `httpRoute`, `serviceMonitor`, `autoscaling`, `networkPolicy`, etc.) — templates are heavily conditional and dead branches hide breakage.

### Release / Versioning Conventions

- **Version bumps are manual**: edit `version` in the chart's `Chart.yaml` (semver). Every chart change requires a version bump.
- Release is a manual `workflow_dispatch` (`.github/workflows/release-charts.yaml`): chart-releaser to GitHub Pages + `helm push` of `.cr-release-packages/*` to GHCR (`CR_SKIP_EXISTING: true`).

### Contribution Rules (enforced by CI / convention)

- **DCO sign-off required** on every commit: `git commit -s`.
- One chart per PR; PRs touching multiple charts are discouraged.
- Docs requirements: every new/changed value must be reflected in the chart's `README.md` parameter table and, if it affects post-install behavior, in `NOTES.txt`.
- Follow Helm best practices: label/annotation conventions, `keycloak.labels`-style helpers on all resources, conditional rendering guards.

### Tooling

- Tools: Helm, chart-testing (`ct`) with Python-based `yamale` and `yamllint` on PATH — both are required by `ct lint` (install via `pip install yamale yamllint` if missing). CI pins its own tool versions in `.github/workflows/lint-test.yaml`.

## Maintainer Workflows

Reviewers and maintainers use two agent workflows for keycloakx (both read-only — they
produce local reports and never change GitHub state):

| Task | Instructions |
|---|---|
| PR review (backwards compatibility) | Read and follow `.agents/skills/keycloakx-pr-review/SKILL.md` |
| Issue triage (reproduce & propose a fix) | Read and follow `.agents/skills/keycloakx-issue-triage/SKILL.md` |

- Intended for maintainers/reviewers of `charts/keycloakx` (see `charts/keycloakx/OWNERS`);
  each skill's `Audience` section defines who should run it and what to do for external
  contributors instead.
- They assume `git`, `gh`, `helm`, `kubectl`, `k3d`, and `ct` (+ `yamale`/`yamllint`) on PATH.
  If a tool or cluster is missing, run the static parts only and say so in the report.

## Ownership / Review

- Repo CODEOWNERS: `@codecentric/helm-charts-contributors`.
- Per-chart approvers/reviewers: see each chart's `OWNERS` file (keycloakx and keycloak have one; mailhog does not). `OWNERS` is the single source of truth — don't duplicate the names elsewhere.
