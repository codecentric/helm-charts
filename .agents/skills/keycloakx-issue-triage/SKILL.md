---
name: keycloakx-issue-triage
description: Maintainer workflow. Analyzes a GitHub issue for the keycloakx Helm chart (codecentric/helm-charts). Use when a maintainer or reviewer asks to look at, triage, analyze, verify, reproduce, or propose a fix for a keycloakx issue (by number or URL). Collects issue context, classifies it, reproduces it locally (helm template and/or live install on the local k3d cluster, reporter's version vs. master), finds the root cause, prepares a proposed fix in a separate local worktree, and dispatches a subagent to independently review the built solution before reporting — WITHOUT committing, pushing, creating a PR or commenting on the issue; the result is a report for the user to review and discuss.
---

# keycloakx issue triage — analyze, reproduce, propose

Goal: turn a GitHub issue into a **verified diagnosis** and a **reviewable fix
proposal**. The user decides what happens next.

## Audience

This workflow is for **maintainers and reviewers of `charts/keycloakx`** (see the
chart's `OWNERS`). It encodes the project's triage rubric.

- If the user is the issue reporter or an external contributor asking for help with
  their own problem, do not run this workflow — answer their questions directly
  instead.
- Acting on the outcome (commenting, closing, labeling, opening a PR) stays a human
  decision; see Hard rules.

## Hard rules

- **No PR. No push. No commit. No issue comments/labels.** Do not run `gh pr create`,
  `git push`, `git commit`, `gh issue comment`/`edit`/`close`. Only offer to do so in
  the final report; act only after the user explicitly says so in a later turn.
- Do not modify the user's current checkout. The proposed fix goes into a separate
  git worktree (step 6).
- k3d cluster: use only the dedicated namespace `issue-<N>` (created by `repro.sh`
  with label `kcx-issue-triage=true`). Never switch the kubectl context, never touch
  other namespaces. Leave the namespace in place for the user's review, but tell
  them how to clean it up.
- Only keycloakx is in scope. If the issue is about `charts/keycloak` (frozen legacy
  chart) or `charts/mailhog`, say so and stop after the analysis.
- Read `charts/keycloakx/AGENTS.md` before analysing templates.
- Be honest about the outcome: "could not reproduce" and "not a chart bug" are
  valid results. Never claim reproduction from an environment failure
  (ImagePullBackOff, missing CRDs, local OOM).

Paths below are relative to the repo root; scripts live in
`.agents/skills/keycloakx-issue-triage/scripts/` (`$S` below).

## Workflow

### 1. Collect context

```bash
S=.agents/skills/keycloakx-issue-triage/scripts
bash $S/issue-context.sh <N>          # issue, comments, version hints, timeline
                                       # (referenced commits + releases, cross-refs),
                                       # error fingerprints, related issues/PRs
```

Extract and write down:
- **Reported versions**: chart version, Keycloak image, Helm, Kubernetes/platform.
  If the chart version is missing, assume the latest release at the issue's creation
  date (see the tag list) and state that assumption.
- **Reporter's values** (copy them verbatim into `/tmp/kcx-issue-<N>/values-reported.yaml`;
  replace secrets/hostnames with dummies).
- **Delivery mechanism**: errors containing `malformed chart or values:` come from
  **terraform-provider-helm** (`lint = true`), not from the Helm CLI — note the provider
  version if mentioned. Terraform `set { type = "string" }` / `set_string` blocks pass
  values as STRINGS, which the schema may reject (use `repro.sh ... --set-string` to
  simulate that).
- **Expected vs. actual behaviour** and the exact error message.
- **Linked commits / PRs / issues (timeline)** — the script's timeline section lists
  commits that reference the issue (including fork-only ones), maps them to the PR that
  merged them and the first release containing them, and cross-referenced issues.
  **A linked commit/PR is not proof of a fix** — read its diff and check whether it
  changes the code path for the reporter's values (in #922 the referencing commit fixed
  a *different* value combination and left the actual bug in place). An open PR may fix
  it (then review it with the keycloakx-pr-review skill instead) — and a fix can itself
  cause a new issue (cross-references like #933).

If essential information is missing (no values, no error), note precisely what to ask
the reporter — but still try a reasonable reproduction.

**Log every assumption the moment you make it.** Whenever you fill a gap the issue
left open — chart/Keycloak/Helm version, platform, delivery tool, reporter's values,
baseline values, terraform provider version — write it down with your reasoning
(e.g. in `/tmp/kcx-issue-<N>/assumptions.md`). All of them go into the report's
Assumptions section (step 7); anything you cannot state confidently belongs in its
open questions instead.

### 2. Classify

Use the table in `references/triage-guide.md` (rendering bug, runtime bug, upgrade
regression, feature request, upstream Keycloak, misconfiguration, already fixed,
duplicate, environment-specific). Feature requests and pure questions skip step 3/4
reproduction — instead verify on `origin/master` that the feature is really missing
or the question's answer.

### 3. Static analysis

- Read the templates/values/schema the issue points at on `origin/master`
  (`git show origin/master:charts/keycloakx/templates/<file>`), and on the reporter's
  version (`git show keycloakx-<X.Y.Z>:charts/keycloakx/...`) if different.
- Check history: `git log --oneline keycloakx-<X.Y.Z>..origin/master -- charts/keycloakx/<file>`
  to see whether it was already touched/fixed.
- Form a **hypothesis** of the root cause before running anything.

### 4. Reproduce locally

Minimal values first, always reporter's version **and** master:

```bash
# Rendering issues — conclusive without a cluster
bash $S/repro.sh template --version <X.Y.Z>       -f /tmp/kcx-issue-<N>/values-reported.yaml
bash $S/repro.sh template --ref origin/master     -f /tmp/kcx-issue-<N>/values-reported.yaml

# Terraform-delivered charts — the "malformed chart or values" error comes from the
# provider's pre-flight lint, not the Helm CLI (newer Helm only warns where old one
# errors). reproduce it faithfully (needs Go; binary cached per Helm version):
bash $S/repro.sh tf-lint  --version <X.Y.Z> -f /tmp/kcx-issue-<N>/values-reported.yaml            # latest provider release
bash $S/repro.sh tf-lint  --version <X.Y.Z> --tf-provider <P.P.P> -f ...                          # specific provider
bash $S/repro.sh tf-lint  --version <X.Y.Z> --helm-lib v3.3.4 -f ...                              # pin the Helm library directly
# also try BOTH the reporter's provider version AND the latest one — behavior differs
# (e.g. helm lib < 3.5 treats invalid metadata names as ERROR, >= 3.5 as WARNING only)

# Runtime issues — live install on k3d into namespace issue-<N>
bash $S/repro.sh install --issue <N> --version <X.Y.Z> -f /tmp/kcx-issue-<N>/values-reported.yaml [--with-postgres] [--set replicas=2]
bash $S/repro.sh install --issue <N> --ref origin/master -f ... --reset

# Upgrade regressions — install old, upgrade to new with the SAME values
bash $S/repro.sh install --issue <N> --version <OLD> -f ...
bash $S/repro.sh upgrade --issue <N> --version <NEW> -f ...

bash $S/repro.sh diag    --issue <N>   # re-collect pods/events/logs
bash $S/repro.sh cleanup --issue <N>   # delete the namespace (only ours)
```

Notes:
- `repro.sh` applies `values/baseline.yaml` (H2 dev-file DB + admin secret) first;
  use `--no-baseline` when the issue concerns defaults or keys from the baseline.
- `--with-postgres` deploys a throw-away PostgreSQL into the namespace and points the
  chart at it.
- Last output line is `RESULT: OK|FAILED|ERROR`. `FAILED` on the reporter's version is
  what "reproduced" looks like; `ERROR` means the script/environment failed.
- Shrink the values until the problem disappears to find the trigger; keep the
  smallest failing file as `/tmp/kcx-issue-<N>/values-minimal.yaml`.
- **Fidelity of `--version X.Y.Z`**: it uses the git tag and falls back to the published
  OCI chart. They are normally identical, but when exact reproduction is disputed,
  verify: `helm repo add codecentric https://codecentric.github.io/helm-charts` →
  `helm pull codecentric/keycloakx --version X.Y.Z --untar` and diff against the tag —
  or pass the pulled dir via `--chart-dir`.
- If a part cannot be reproduced on k3d (OpenShift Route, Gateway API CRDs, service
  mesh, cloud LB), reproduce what you can (rendered manifests) and state the gap.

**If it does NOT reproduce with the current tooling, vary the reproduction before
concluding "not reproducible"** — the error may live in the consumer's embedded Helm
version, not the chart:
- try other Helm majors/minors (`mise exec helm@3 -- helm template/lint ...`);
- try `repro.sh tf-lint` with the reporter's provider version AND older ones
  (provider ≤ v2.0.x bundles helm 3.3.4, where lint errors are today's warnings);
- consult the tool-fingerprint table in `references/triage-guide.md` to identify the
  tool that produced the exact error string (and how to read its source at the
  relevant version).

Verdict for this step — exactly one of:
- **Valid (reproduced)** on version X (and on master → still open, or not on master → already fixed in `<commit/release>`).
- **Not reproducible** — only after varying tool versions/delivery mechanisms; state
  what was tried and what info is missing (provider version, full values, Helm/K8s
  versions — ask the reporter).
- **Not a chart bug** — misconfiguration (show the correct values) or upstream Keycloak.
- **Feature request** — confirmed missing on master.

### 5. Root cause

Pinpoint file + line(s) on `origin/master` and explain *why* it breaks (quote the
template snippet and the rendered/error output). For "already fixed", identify the
fixing commit (`git log -S '<snippet>'`, `git bisect` between tags if needed).

### 6. Propose the fix (only for valid bugs / accepted feature requests)

Create an isolated worktree on a new local branch — never commit there:

```bash
git fetch origin
git worktree add ../helm-charts-issue-<N> -b fix/keycloakx-issue-<N> origin/master
```

In `../helm-charts-issue-<N>`:
1. Make the minimal fix (templates / schema / values).
2. Do NOT change `charts/keycloakx/Chart.yaml` `version` — version bumping and
   releasing is a maintainer task; flag the intended bump level (patch/minor/major)
   in the report instead. `appVersion` updates for a newer Keycloak image are fine.
3. Update README parameter table / `NOTES.txt` if values or post-install behaviour change.
4. Add regression coverage where sensible (e.g. a `charts/keycloakx/ci/<topic>-values.yaml`
   that would have failed before; it must install on kind with H2).
5. Use a Conventional Commits subject for every commit (`fix(keycloakx): ...`),
   including intermediate ones — the `commit-lint` CI check enforces it on every
   PR commit, and merges to master are rebase merges, so every subject lands on
   the history.

Verify the fix:

```bash
F=../helm-charts-issue-<N>/charts/keycloakx
bash $S/repro.sh template --chart-dir $F -f /tmp/kcx-issue-<N>/values-minimal.yaml    # now OK
bash $S/repro.sh install  --chart-dir $F -f /tmp/kcx-issue-<N>/values-minimal.yaml --issue <N> --reset   # if runtime bug
helm lint $F && helm lint $F -f $F/ci/h2-values.yaml
ct lint --config ct.yaml --charts charts/keycloakx    # run inside the worktree, if yamale/yamllint available
```

Backwards-compat check against master (reuse the PR review skill on the worktree):

```bash
(cd ../helm-charts-issue-<N> && bash "$OLDPWD/.agents/skills/keycloakx-pr-review/scripts/render-diff.sh" origin/master WORKTREE)
```

Default-values output must be unchanged apart from version labels unless the change is
intentionally behavioural (then call it out).

If several solutions are plausible, implement the one you recommend and describe the
alternatives with trade-offs in the report — the user wants to discuss.

**Independent review of the built solution — dispatch a subagent.** You authored the
fix, and authorship is a blind spot: before writing the report, have a second agent
review it. In order of preference:

1. **Dispatch a subagent** if your harness supports parallel agent runs.
2. Otherwise run the review in a **fresh context** (a new session that has not seen
   this analysis).
3. Minimum fallback: re-read the issue and the diff cold, then critique the change
   as if someone else had written it.

Brief for the reviewing agent (adjust placeholders, deliver verbatim):

> You are independently reviewing a proposed fix for the keycloakx Helm chart.
> Worktree: `../helm-charts-issue-<N>` (branch `fix/keycloakx-issue-<N>`); the change
> is uncommitted — review `git -C ../helm-charts-issue-<N> diff`.
>
> 1. Read the issue first: `gh issue view <N>`. Form your own root-cause hypothesis
>    BEFORE reading anyone else's analysis, then compare it with what this fix implies.
> 2. Review the diff: does it fix the actual trigger (see
>    `/tmp/kcx-issue-<N>/values-minimal.yaml`)? Is it the minimal change? What else
>    renders differently now (values, templates, NOTES) that it should not touch?
> 3. Check conventions: `Chart.yaml` `version` UNCHANGED (maintainer-only;
>    bump level flagged in the report), `values.schema.json`, README parameter
>    table, `NOTES.txt` for post-install changes.
> 4. Backwards compatibility — from the repo root:
>    `(cd ../helm-charts-issue-<N> && bash "$OLDPWD/.agents/skills/keycloakx-pr-review/scripts/render-diff.sh" origin/master WORKTREE)`
>    Defaults must render identically apart from version labels unless the change is
>    intentionally behavioral. The full rubric is
>    `.agents/skills/keycloakx-pr-review/SKILL.md`.
> 5. If you doubt the fix, re-run the reproduction yourself (no cluster needed):
>    `bash .agents/skills/keycloakx-issue-triage/scripts/repro.sh template --chart-dir ../helm-charts-issue-<N>/charts/keycloakx -f /tmp/kcx-issue-<N>/values-minimal.yaml`
>
> Hard rules for you: strictly read-only — no commits, no pushes, no writes to the
> issue, PRs, the worktree, or the user's main checkout.
>
> Return: a BLOCKER / SHOULD-FIX / NOTE findings list with evidence (diff hunks,
> render-diff output), and a verdict: "sound" or "needs changes".

Fold the findings into the report: address each valid finding, dispute the rest with
reasoning — then stop. **Exactly one review round**: never dispatch a second review
of the same proposal, not even after addressing findings — changes made in response
to the review are documented in the report, not re-reviewed. An unresolved BLOCKER is
reported as an open problem; the user decides what happens next.

### 7. Report (end of the turn — then stop)

```
## keycloakx issue #<N> — <title>

### Summary
<1–3 sentences: what the reporter sees, classification, verdict>

### Context
- reported: chart <X.Y.Z>, Keycloak <..>, Helm <..>, platform <..>
- related: <duplicates / open PRs / fixing commits, or "none">

### Assumptions
These were filled in on the reporter's behalf because the issue did not state them —
the reader must be able to judge how much of the analysis rests on each one. Include
the tooling defaults you reproduced with (local Helm version, baseline values,
k3d platform, provider version) — they are assumptions too.

| # | Not stated in the issue | Assumed | Risk if wrong |
|---|---|---|---|
| 1 | chart version | keycloakx-<X.Y.Z> — latest release at issue creation (<date>) | bug may already be fixed / not yet exist |
| 2 | delivery tool | plain `helm` CLI (no error fingerprint found) | error may only reproduce in terraform-provider-helm / ArgoCD |
| 3 | platform | local single-node k3d | platform-specific behavior only checked as rendered manifests |
| … | <further assumptions from steps 1–6> | | |

### Reproduction
| Chart source | Mode | Values | Result |
|---|---|---|---|
| keycloakx-<X.Y.Z> | template/install | values-minimal.yaml | FAILED — <error> |
| origin/master | ... | ... | FAILED / OK |
Minimal values: <inline yaml>
Evidence: <error output / rendered snippet / pod logs>

### Root cause
<file:line on master, quoted snippet, explanation>

### Proposed fix
- worktree: ../helm-charts-issue-<N> (branch fix/keycloakx-issue-<N>, uncommitted)
- diff: <`git -C ../helm-charts-issue-<N> diff` — full if short, summarised if long>
- chart version: <old> → <new>
- verification: repro after fix OK, helm lint OK, render-diff defaults <identical/changes>, ct lint <ok/skipped>
- alternatives considered: <...>
- open questions for discussion: <...>

### Independent review (subagent)
- reviewer: <fresh subagent / fresh session, keycloakx-pr-review rubric>
- verdict: <sound / needs changes>
- findings: <BLOCKER / SHOULD-FIX / NOTE list, or "none">
- author's response: <each finding addressed — or disputed, with reasoning>

### Draft PR (not created)
Title: [keycloakx] <...>
Body: Fixes #<N>. <what/why/how tested>

### Next steps (waiting for your decision)
- discuss / adjust the proposal
- on approval: commit with sign-off (`git commit -s`), push, `gh pr create`
- cleanup: `bash .agents/skills/keycloakx-issue-triage/scripts/repro.sh cleanup --issue <N>`;
  `git worktree remove ../helm-charts-issue-<N> && git branch -D fix/keycloakx-issue-<N>`
```

For invalid / not-reproducible / not-a-chart-bug issues, replace "Proposed fix" with a
**proposed answer to the reporter** (draft text only, not posted) and what info to request.

## Troubleshooting

- `RESULT: ERROR — not a valid git ref: keycloakx-X.Y.Z` → `git fetch origin --tags`;
  `--version` falls back to the GHCR OCI chart automatically.
- `tf-lint` fails to build → check `go version` (needs Go); the build dir is
  `${XDG_CACHE_HOME:-~/.cache}/kcx-issue-triage/tf-lint-<helm-version>/` — delete it to
  force a rebuild. `--helm-lib` lets you pin any Helm library version when you can't
  resolve the reporter's provider version.
- `RESULT: ERROR — not a valid git ref: keycloakx-X.Y.Z` → `git fetch origin --tags`;
  `--version` falls back to the GHCR OCI chart automatically.
- `namespace 'issue-<N>' already exists` → `--reset` (only works for namespaces created
  by this skill), or `upgrade` to keep the existing release.
- Stale temp worktrees after an interrupted run → `git worktree prune`.
- Replica >1 stuck `Pending` with `didn't match pod anti-affinity rules` → single-node
  cluster vs. the chart's required anti-affinity default; re-run with `--set affinity=""`
  (see `references/triage-guide.md`).
- Pods stuck `Pending` otherwise → check node resources (`kubectl --context <ctx> describe node`);
  the local cluster may be busy with other work.
