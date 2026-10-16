---
name: keycloakx-pr-review
description: Maintainer workflow. Reviews keycloakx Helm chart pull requests for backwards compatibility. Use when a maintainer or reviewer asks to review, check, sanity-check, or test a PR (by number, branch, commit, or the current working tree) that touches charts/keycloakx. Renders before/after manifests and diffs them, checks values/schema/versioning/docs, optionally runs a live install-and-upgrade test of the PR on the local k3d cluster, and reports either concrete issues or a "good to go" verdict.
---

# keycloakx PR review — backwards compatibility

Review a PR against the keycloakx chart with one question in focus: **does this change
break, or risk breaking, users who upgrade an existing installation?**

The chart is deployed as a StatefulSet by many production users. Typical breakage is
subtle: a changed default silently altering rendered manifests, a renamed value, a
schema that rejects previously valid values, an immutable StatefulSet field, or a
behavior change in the generated `KC_*` environment. Both scripts bundled here are
built to surface exactly those.

## Audience

This workflow is for **maintainers and reviewers of `charts/keycloakx`** (see the
chart's `OWNERS`). It encodes the project's review rubric for backwards
compatibility.

- If the user is an external contributor asking about their own PR, do not run this
  workflow — answer their questions directly instead.
- Merging and approving remain human decisions regardless of the verdict; this
  workflow produces a local report only.

## Scope

- Only reviews PRs touching `charts/keycloakx`. If the PR touches `charts/keycloak`
  or `charts/mailhog` (both excluded from CI), say so and review manually without
  the scripts — repo rules require one chart per PR anyway.
- The review is read-only: never commit, push, or comment on the PR unless the user
  explicitly asks. Findings go into the report you produce.
- If charts/keycloakx/AGENTS.md exists, read it first for chart-specific context.

## Ground rules for the k3d cluster

- The local k3d cluster may host other work (the user's namespaces, e.g. `pr<number>`,
  `platform`, `cnpg-system`). Isolate everything in ONE dedicated namespace
  (convention: `pr<number>` for PR testing) and delete only that namespace.
- Never change the current kubectl context (scripts use `--context`/`--kube-context`).
- The scripts never touch resources outside the namespace/release they manage.

## Workflow

### 1. Identify the change under review

Input is one of: a PR number, a branch, a commit, or the current working tree
("what I have checked out"). Resolve it into a git ref:

```bash
# With a PR number (recommended):
git fetch origin --prune
git fetch origin pull/<N>/head:refs/remotes/pr/<N>     # PR head as a ref
gh pr view <N> --json number,title,author,baseRefName,headRefName,files,body  # context (optional)

# BASE ref is the PR's target branch, usually:
origin/master
# HEAD ref is:
refs/remotes/pr/<N>   # or a branch / sha
WORKTREE              # special token: the current checkout incl. uncommitted changes
```

If there is no PR and no branch, review `WORKTREE` as the head against `origin/master`.

Read the actual diff before running anything: `git diff $(git merge-base origin/master <HEAD>) <HEAD> -- charts/keycloakx`.
Understand what the PR intends — you cannot judge "breaking" without knowing "intended".

### 2. Static backwards-compat check

Manually inspect the files that carry compat risk (details and examples:
`references/compat-checklist.md`):

| File | What breaks users |
|---|---|
| `Chart.yaml` | version not bumped; appVersion/image.tag out of sync |
| `values.yaml` | changed DEFAULTS (affects everyone); removed/renamed values; tpl-values that stopped being strings |
| `values.schema.json` | new `required`; removed properties; narrowed types; `additionalProperties: false` |
| `templates/*` | selector/label changes (immutable!); resource/port/env renames; helper output changes |
| `README.md` / `NOTES.txt` | missing documentation for new/changed values (repo docs contract) |

Then run the render-diff (from the repo root, adjust path to wherever this skill lives):

```bash
bash .agents/skills/keycloakx-pr-review/scripts/render-diff.sh origin/master refs/remotes/pr/<N>
# or for the current working tree:
bash .agents/skills/keycloakx-pr-review/scripts/render-diff.sh origin/master WORKTREE
```

It renders the merge-base chart ("before") and the PR ("after") with three value
profiles (defaults / kitchen-sink / ci) and prints unified diffs.

Interpret:

- `defaults: IDENTICAL` (only version labels changed) — good.
- `defaults: CHANGED` beyond `helm.sh/chart:` / `app.kubernetes.io/version:` /
  `image:` / `checksum/*` noise — every existing user is affected. BLOCKER unless
  clearly intentional AND version-bumped appropriately (major/minor) AND documented
  in README (+ `NOTES.txt` if post-install behavior changes).
- `kitchen-sink` hunks: additive output for newly enabled opt-in features is fine;
  changed output of previously existing resources is not.
- `REGRESSION — head fails to render where base succeeded` — BLOCKER, always.
- Optional `ct lint --config ct.yaml --charts charts/keycloakx` if `yamale` and
  `yamllint` are on PATH (`pip install yamale yamllint`); otherwise note it was skipped.

### 3. Live test on the k3d cluster (recommended)

Simulates the actual user experience of upgrading:

```bash
bash .agents/skills/keycloakx-pr-review/scripts/k3d-live-test.sh \
  --head-ref refs/remotes/pr/<N> \
  --namespace pr<N> \
  --cluster digitalidentity          # optional; auto-detected otherwise
```

It installs the merge-base chart with a minimal review values file (H2 dev-file DB,
no external dependencies), waits for health, then `helm upgrade`s to the PR chart
**with the identical values file** — a PR that needs new required values will fail
here — and checks rollout + readiness endpoint.

- Re-running for an updated PR: add `--reset`, or `kubectl delete ns pr<N>` first.
- Debugging a stuck test: add `--keep`, then inspect the namespace yourself
  (`kubectl -n pr<N> describe sts kcx-review-keycloakx`, `kubectl -n pr<N> logs ...`).
- On failure the namespace is kept automatically; always clean it up when done.

Failure signatures and what they mean:

- `field is immutable` (helm upgrade error) — selector/labels change. BLOCKER.
- `helm upgrade` failed on schema validation — previously valid values now rejected. BLOCKER.
- Pods CrashLoopBackOff / stuck rollout but upgrade rendered fine — functional
  regression (split bug report section in the script's output). Investigate logs
  before reporting; could be environment (e.g. image pull) — check the diagnosis.
- ImagePullBackOff — environment issue (no quay.io access), not the PR. Say so and
  skip the live part.

If no cluster is available (`k3d cluster list` empty) the script creates and deletes
an ephemeral one — with `--cluster` you explicitly pick one.

### 4. Report

Format (always include the verdict — the user asked for exactly this):

```
## keycloakx PR #<N> — backwards compatibility review

### Summary
<1–3 sentences on what the PR does + chart version before → after>

### Static analysis
- render-diff: <profiles changed, key hunks or "only expected version-label noise">
- values/schema/README/NOTES: <findings per file>

### Live test (k3d: <cluster>, ns: <namespace>)
- install base <version>: ok
- upgrade to <version> with unchanged values: ok / FAILED <error>
- rollout + health endpoint: ok / FAILED <error>

### Findings
| # | Severity | Issue | Evidence |
|---|----------|-------|----------|

### Verdict
```

Severity ladder (details in `references/compat-checklist.md`):

- `BLOCKER` — rendered output changed for unchanged values unintentionally; head
  render fails where base rendered; schema rejects previously valid values; values
  removed/renamed without alternative; immutable-field (selector) changes; chart
  version not bumped; live upgrade fails or pods crash.
- `SHOULD-FIX` — README parameter table not updated; NOTES.txt missing for changed
  post-install behavior; version bump too small for an intentional behavior change;
  deprecation notice missing.
- `NOTE` — expected diffs (version labels, image tag, checksums); additive opt-in features.

Verdict:

- ⛔ **NOT good to go** — one or more BLOCKERs (list them with concrete fixes).
- ⚠️ **Good to go, with fixes recommended** — only SHOULD-FIX items remain.
- ✅ **Good to go** — no backwards-compatibility issues found.

Always quote evidence (diff hunks, kubectl output) for every finding.

## Troubleshooting

- Interrupted runs leave nothing behind except (rarely) a namespace — check
  `kubectl get ns | grep -E 'kcx-review|pr'` and stale `git worktree list` entries
  (`git worktree prune`).
- `helm template` errors from the kitchen-sink profile ON THE BASE SIDE with BASE-FAILS-HEAD-OK
  status: expected when the PR introduces genuinely new values — cross-check that
  the failure is caused by the new feature, not by a regression.
- The scripts resolve chart version, worktrees and namespaces themselves; every
  diagnostic they need for triage is in their stdout. Keep that output for the report.
