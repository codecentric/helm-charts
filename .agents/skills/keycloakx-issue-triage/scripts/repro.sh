#!/usr/bin/env bash
# repro.sh — reproduce a keycloakx chart issue locally (helm template and/or a
# live install on the local k3d cluster) and collect diagnostics.
#
# Usage:
#   repro.sh template  [chart-source] [values]          [-o FILE]
#   repro.sh install   [chart-source] [values] [cluster] [--reset] [--timeout SECS]
#   repro.sh upgrade   [chart-source] [values] [cluster] [--timeout SECS]
#   repro.sh diag                              [cluster]
#   repro.sh cleanup                           [cluster]
#   repro.sh tf-lint   [chart-source] [values] [--tf-provider X.Y.Z | --helm-lib vX.Y.Z]
#
# tf-lint reproduces terraform-provider-helm's pre-flight lint (`lint = true`,
# errors start with "malformed chart or values:") by calling Helm's lint
# library exactly like the provider. --tf-provider resolves the Helm library
# version from the provider's go.mod (default: the provider's latest tag);
# --helm-lib pins it directly. Needs Go; the binary is cached per version in
# ${XDG_CACHE_HOME:-~/.cache}/kcx-issue-triage/. tf-lint does NOT apply the
# baseline values (Terraform passes only the user's values) unless --baseline.
#
# Chart source (pick one, default: --ref origin/master):
#   --ref REF          any git ref (branch, sha, tag e.g. keycloakx-7.3.0), or
#                      WORKTREE for the current checkout incl. uncommitted changes
#   --chart-dir DIR    an explicit chart directory (e.g. a fix worktree)
#   --version X.Y.Z    a released chart version: uses git tag keycloakx-X.Y.Z,
#                      falls back to oci://ghcr.io/codecentric/helm-charts/keycloakx
#
# Values:
#   -f FILE            values file (repeatable, applied after the baseline)
#   --set K=V          helm --set (repeatable)
#   --set-string K=V   helm --set-string (repeatable) — Terraform `set` blocks
#                      with type = "string" / `set_string` behave like this
#   --baseline         force baseline values (only relevant for tf-lint)
#   --no-baseline      do NOT apply values/baseline.yaml (H2 dev-file + admin
#                      secret). Use when the reporter's values fully replace it.
#   --with-postgres    deploy a throw-away PostgreSQL into the namespace and
#                      apply values/postgres.yaml (install/upgrade only)
#
# Cluster / naming:
#   --issue N          sets defaults: namespace issue-N, release kcx-issue
#   --namespace NAME   default issue-<N> (or kcx-issue-<pid> without --issue)
#   --release NAME     default kcx-issue
#   --cluster NAME     k3d cluster (default: current k3d context, else first
#                      running k3d cluster)
#   --reset            install: delete and recreate the namespace first
#   --timeout SECS     wait timeout for install/upgrade (default 600)
#
# Exit code / last line:
#   RESULT: OK ...       command succeeded (rendered / installed and healthy)
#   RESULT: FAILED ...   rendering, install, rollout or readiness failed —
#                        for a bug report this usually means "reproduced"
#   RESULT: ERROR ...    the script itself could not run (bad args, no cluster)
#
# Safety:
#   * never switches the current kubectl context (always --context)
#   * namespaces are created with label kcx-issue-triage=true; cleanup/--reset
#     refuse to delete namespaces without that label
#   * the namespace is never deleted automatically — run `repro.sh cleanup`

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASELINE_VALUES="$SKILL_DIR/values/baseline.yaml"
POSTGRES_VALUES="$SKILL_DIR/values/postgres.yaml"
POSTGRES_MANIFEST="$SKILL_DIR/manifests/postgres.yaml"
CHART_REL_PATH="charts/keycloakx"
OCI_CHART="oci://ghcr.io/codecentric/helm-charts/keycloakx"
NS_LABEL="kcx-issue-triage"

TMP_PATHS=()
cleanup_tmp() {
    local p
    for p in "${TMP_PATHS[@]:-}"; do
        [ -n "$p" ] || continue
        if [ -d "$p/chart/.git" ] || [ -f "$p/chart/.git" ]; then
            git worktree remove --force "$p/chart" >/dev/null 2>&1 || true
        fi
        rm -rf "$p"
    done
    git worktree prune >/dev/null 2>&1 || true
}
trap cleanup_tmp EXIT

err()    { echo "RESULT: ERROR — $*"; exit 2; }
failed() { echo; echo "RESULT: FAILED — $*"; exit 1; }
ok()     { echo; echo "RESULT: OK — $*"; exit 0; }

usage() { awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$0"; }

[ $# -gt 0 ] || { usage; exit 2; }
CMD="$1"; shift
case "$CMD" in
    template|install|upgrade|diag|cleanup|tf-lint) ;;
    -h|--help) usage; exit 0 ;;
    *) err "unknown command: $CMD (expected template|install|upgrade|diag|cleanup|tf-lint)" ;;
esac

SRC_REF=""; SRC_DIR=""; SRC_VERSION=""
VALUES_FILES=(); SET_ARGS=()
USE_BASELINE=1; WITH_PG=0; FORCE_BASELINE=0
TF_PROVIDER=""; HELM_LIB=""
ISSUE=""; NS=""; RELEASE="kcx-issue"; CLUSTER=""
RESET=0; TIMEOUT=600; OUT_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --ref) SRC_REF="$2"; shift 2 ;;
        --chart-dir) SRC_DIR="$2"; shift 2 ;;
        --version) SRC_VERSION="$2"; shift 2 ;;
        -f|--values) [ -f "$2" ] || err "values file not found: $2"; VALUES_FILES+=("$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"); shift 2 ;;
        --set) SET_ARGS+=(--set "$2"); shift 2 ;;
        --set-string) SET_ARGS+=(--set-string "$2"); shift 2 ;;
        --no-baseline) USE_BASELINE=0; shift ;;
        --baseline) FORCE_BASELINE=1; shift ;;
        --tf-provider) TF_PROVIDER="${2#v}"; shift 2 ;;
        --helm-lib) HELM_LIB="v${2#v}"; shift 2 ;;
        --with-postgres) WITH_PG=1; shift ;;
        --issue) ISSUE="$2"; shift 2 ;;
        --namespace) NS="$2"; shift 2 ;;
        --release) RELEASE="$2"; shift 2 ;;
        --cluster) CLUSTER="$2"; shift 2 ;;
        --reset) RESET=1; shift ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        -o) OUT_FILE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) err "unknown argument: $1" ;;
    esac
done

[ -n "$NS" ] || NS="${ISSUE:+issue-$ISSUE}"
[ -n "$NS" ] || NS="kcx-issue-$$"

for b in git helm; do command -v "$b" >/dev/null 2>&1 || err "$b not found on PATH"; done
echo "# local helm: $(helm version --short 2>/dev/null)  (reporter's Helm major may differ — Helm 3 and 4 validate differently)"

# ---------------------------------------------------------------------------
# Chart source resolution
# ---------------------------------------------------------------------------
CHART=""
CHART_DESC=""
resolve_chart() {
    local n=0
    [ -n "$SRC_REF" ] && n=$((n+1))
    [ -n "$SRC_DIR" ] && n=$((n+1))
    [ -n "$SRC_VERSION" ] && n=$((n+1))
    [ "$n" -le 1 ] || err "use only one of --ref / --chart-dir / --version"
    [ "$n" -eq 1 ] || SRC_REF="origin/master"

    if [ -n "$SRC_DIR" ]; then
        [ -f "$SRC_DIR/Chart.yaml" ] || err "no Chart.yaml in $SRC_DIR"
        CHART="$(cd "$SRC_DIR" && pwd)"
        CHART_DESC="dir $CHART"
        return
    fi

    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null) || err "not inside the helm-charts git repository"

    if [ -n "$SRC_VERSION" ]; then
        if git -C "$root" rev-parse -q --verify "refs/tags/keycloakx-$SRC_VERSION" >/dev/null; then
            SRC_REF="keycloakx-$SRC_VERSION"
        else
            local tmp
            tmp=$(mktemp -d "${TMPDIR:-/tmp}/kcx-issue-oci-XXXXXX"); TMP_PATHS+=("$tmp")
            helm pull "$OCI_CHART" --version "$SRC_VERSION" --untar --untardir "$tmp" >/dev/null 2>&1 \
                || err "chart version $SRC_VERSION neither a git tag (keycloakx-$SRC_VERSION) nor pullable from $OCI_CHART"
            CHART="$tmp/keycloakx"
            CHART_DESC="released $SRC_VERSION (OCI)"
            return
        fi
    fi

    if [ "$SRC_REF" = "WORKTREE" ]; then
        CHART="$root/$CHART_REL_PATH"
        CHART_DESC="current worktree ($root)"
        return
    fi

    git -C "$root" rev-parse -q --verify "$SRC_REF^{commit}" >/dev/null || err "not a valid git ref: $SRC_REF (git fetch origin --tags?)"
    local tmp
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/kcx-issue-ref-XXXXXX"); TMP_PATHS+=("$tmp")
    git -C "$root" worktree add --detach "$tmp/chart" "$SRC_REF" >/dev/null 2>&1 || err "git worktree add failed for $SRC_REF"
    CHART="$tmp/chart/$CHART_REL_PATH"
    [ -d "$CHART" ] || err "$CHART_REL_PATH does not exist at $SRC_REF"
    CHART_DESC="ref $SRC_REF ($(git -C "$root" rev-parse --short "$SRC_REF^{commit}"))"
}

values_args() {
    VARGS=()
    [ "$USE_BASELINE" = 1 ] && VARGS+=(-f "$BASELINE_VALUES")
    [ "$WITH_PG" = 1 ] && VARGS+=(-f "$POSTGRES_VALUES")
    local f
    for f in "${VALUES_FILES[@]:-}"; do [ -n "$f" ] && VARGS+=(-f "$f"); done
    VARGS+=("${SET_ARGS[@]:-}")
    # drop empty element produced by an empty SET_ARGS expansion
    local clean=() a
    for a in "${VARGS[@]}"; do [ -n "$a" ] && clean+=("$a"); done
    VARGS=("${clean[@]}")
}

chart_version() { helm show chart "$1" 2>/dev/null | awk '/^version:/ {v=$2} /^appVersion:/ {a=$2} END {print v" (appVersion "a")"}'; }

# ---------------------------------------------------------------------------
# Cluster resolution (never switches the current context)
# ---------------------------------------------------------------------------
CTX=""
resolve_cluster() {
    command -v kubectl >/dev/null 2>&1 || err "kubectl not found on PATH"
    command -v k3d >/dev/null 2>&1 || err "k3d not found on PATH"
    if [ -n "$CLUSTER" ]; then
        k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$CLUSTER" || err "k3d cluster '$CLUSTER' not found"
        CTX="k3d-$CLUSTER"
    else
        local cur
        cur=$(kubectl config current-context 2>/dev/null || true)
        if [ "${cur#k3d-}" != "$cur" ]; then
            CTX="$cur"
        else
            local first
            first=$(k3d cluster list 2>/dev/null | awk 'NR==2 {print $1}')
            [ -n "$first" ] || err "no k3d cluster running — ask the user to start one (k3d cluster list)"
            CTX="k3d-$first"
        fi
    fi
    kubectl config get-contexts -o name 2>/dev/null | grep -qx "$CTX" \
        || k3d kubeconfig merge "${CTX#k3d-}" --kubeconfig-merge-default >/dev/null 2>&1 \
        || err "context $CTX not in kubeconfig and merge failed"
    kubectl --context "$CTX" get --raw /readyz >/dev/null 2>&1 || err "cluster not reachable via context $CTX"
}

kc() { kubectl --context "$CTX" "$@"; }
hm() { helm --kube-context "$CTX" -n "$NS" "$@"; }

ns_is_ours() {
    [ "$(kc get ns "$NS" -o jsonpath="{.metadata.labels.$NS_LABEL}" 2>/dev/null)" = "true" ]
}

delete_ns() {
    kc get ns "$NS" >/dev/null 2>&1 || return 0
    ns_is_ours || err "namespace '$NS' exists but was not created by this skill (missing label $NS_LABEL=true) — refusing to delete it"
    echo "deleting namespace $NS ..."
    kc delete ns "$NS" --wait --timeout="${TIMEOUT}s" >/dev/null
}

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------
diagnostics() {
    echo
    echo "=== diagnostics: namespace $NS (context $CTX) ==="
    echo "--- helm release history ---"
    hm history "$RELEASE" 2>&1 || true
    echo "--- workloads / pods ---"
    kc -n "$NS" get sts,deploy,pods,svc,pvc -o wide 2>&1 || true
    echo "--- warning events (latest 30) ---"
    kc -n "$NS" get events --field-selector type=Warning --sort-by=.lastTimestamp 2>/dev/null | tail -30 || true
    local pod c
    for pod in $(kc -n "$NS" get pods -l "app.kubernetes.io/instance=$RELEASE" -o name 2>/dev/null); do
        echo "--- $pod: container states ---"
        kc -n "$NS" get "$pod" -o jsonpath='{range .status.initContainerStatuses[*]}init/{.name}: ready={.ready} restarts={.restartCount} state={.state}{"\n"}{end}{range .status.containerStatuses[*]}{.name}: ready={.ready} restarts={.restartCount} state={.state} lastState={.lastState}{"\n"}{end}' 2>/dev/null || true
        for c in $(kc -n "$NS" get "$pod" -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null); do
            echo "--- $pod/$c: logs (tail 60) ---"
            kc -n "$NS" logs "$pod" -c "$c" --tail=60 2>&1 || true
            if kc -n "$NS" logs "$pod" -c "$c" --previous --tail=1 >/dev/null 2>&1; then
                echo "--- $pod/$c: PREVIOUS logs (tail 60) ---"
                kc -n "$NS" logs "$pod" -c "$c" --previous --tail=60 2>&1 || true
            fi
        done
    done
    if kc -n "$NS" get events --field-selector type=Warning 2>/dev/null | grep -qE 'ErrImagePull|ImagePullBackOff|FailedScheduling|OOMKilled|no matches for kind'; then
        echo
        echo "HINT: environment-type failure detected (image pull / scheduling / OOM / missing CRD) —"
        echo "      verify it is not a local-environment problem before calling the issue reproduced."
    fi
}

check_ready() {
    local sts
    sts=$(kc -n "$NS" get sts -l "app.kubernetes.io/instance=$RELEASE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    [ -n "$sts" ] || return 1
    kc -n "$NS" rollout status "sts/$sts" --timeout=30s >/dev/null 2>&1 || return 1
    local not_ready
    not_ready=$(kc -n "$NS" get pods -l "app.kubernetes.io/instance=$RELEASE" --no-headers 2>/dev/null \
        | awk '{split($2,a,"/"); if (a[1]!=a[2] || $3!="Running") c++} END {print c+0}')
    [ "$not_ready" = 0 ]
}

deploy_postgres() {
    echo "deploying throw-away PostgreSQL into $NS ..."
    kc -n "$NS" apply -f "$POSTGRES_MANIFEST" >/dev/null
    kc -n "$NS" rollout status deploy/postgres --timeout="${TIMEOUT}s" >/dev/null || failed "postgres did not become ready (environment problem, not the chart)"
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
case "$CMD" in
template)
    resolve_chart; values_args
    echo "=== helm template: $CHART_DESC — chart $(chart_version "$CHART") ==="
    echo "values: ${VARGS[*]:-(chart defaults)}"
    OUT="${OUT_FILE:-$(mktemp "${TMPDIR:-/tmp}/kcx-issue-render-XXXXXX.yaml")}"
    if helm template "$RELEASE" "$CHART" -n "$NS" "${VARGS[@]}" >"$OUT" 2>"$OUT.err"; then
        echo "rendered $(grep -c '^kind:' "$OUT") resources -> $OUT"
        grep '^kind:' "$OUT" | sort | uniq -c | sed 's/^/  /'
        rm -f "$OUT.err"
        ok "rendered successfully ($OUT)"
    else
        cat "$OUT.err"
        failed "helm template failed (stderr above, also in $OUT.err)"
    fi
    ;;

install)
    resolve_chart; values_args; resolve_cluster
    echo "=== install: $CHART_DESC — chart $(chart_version "$CHART") ==="
    echo "cluster: $CTX   namespace: $NS   release: $RELEASE   timeout: ${TIMEOUT}s"
    echo "values: ${VARGS[*]:-(chart defaults)}"
    if kc get ns "$NS" >/dev/null 2>&1; then
        [ "$RESET" = 1 ] || err "namespace '$NS' already exists — use --reset, 'upgrade', or another --namespace"
        delete_ns
    fi
    kc create ns "$NS" >/dev/null
    kc label ns "$NS" "$NS_LABEL=true" >/dev/null
    [ "$WITH_PG" = 1 ] && deploy_postgres
    if ! hm install "$RELEASE" "$CHART" "${VARGS[@]}" --wait --timeout "${TIMEOUT}s"; then
        diagnostics
        failed "helm install did not succeed / did not become ready within ${TIMEOUT}s (namespace $NS kept)"
    fi
    if ! check_ready; then
        diagnostics
        failed "installed, but StatefulSet pods are not all Running/Ready (namespace $NS kept)"
    fi
    kc -n "$NS" get pods -o wide
    ok "installed and healthy: $CHART_DESC in $NS (cleanup: repro.sh cleanup --namespace $NS)"
    ;;

upgrade)
    resolve_chart; values_args; resolve_cluster
    kc get ns "$NS" >/dev/null 2>&1 || err "namespace '$NS' does not exist — run 'install' first"
    echo "=== upgrade: $RELEASE in $NS -> $CHART_DESC — chart $(chart_version "$CHART") ==="
    echo "values: ${VARGS[*]:-(chart defaults)}"
    [ "$WITH_PG" = 1 ] && ! kc -n "$NS" get deploy/postgres >/dev/null 2>&1 && deploy_postgres
    if ! hm upgrade "$RELEASE" "$CHART" "${VARGS[@]}" --wait --timeout "${TIMEOUT}s"; then
        diagnostics
        failed "helm upgrade failed (immutable field? schema? readiness?) — namespace $NS kept"
    fi
    if ! check_ready; then
        diagnostics
        failed "upgraded, but StatefulSet pods are not all Running/Ready"
    fi
    kc -n "$NS" get pods -o wide
    ok "upgraded and healthy: $CHART_DESC in $NS"
    ;;

diag)
    resolve_cluster
    kc get ns "$NS" >/dev/null 2>&1 || err "namespace '$NS' does not exist"
    diagnostics
    ok "diagnostics collected for $NS"
    ;;

cleanup)
    resolve_cluster
    kc get ns "$NS" >/dev/null 2>&1 || ok "namespace '$NS' does not exist — nothing to do"
    delete_ns
    ok "namespace $NS deleted"
    ;;

tf-lint)
    command -v go >/dev/null 2>&1 || err "go not found on PATH (needed to build the tf-lint helper)"
    resolve_chart
    [ "$FORCE_BASELINE" = 1 ] || USE_BASELINE=0
    values_args
    if [ -z "$HELM_LIB" ]; then
        if [ -z "$TF_PROVIDER" ]; then
            TF_PROVIDER=$(gh api 'repos/hashicorp/terraform-provider-helm/releases/latest' -q .tag_name 2>/dev/null | sed 's/^v//') \
                || err "could not determine latest terraform-provider-helm release (pass --tf-provider or --helm-lib)"
            echo "# no --tf-provider given — using latest provider release v$TF_PROVIDER (ask the reporter for theirs)"
        fi
        HELM_LIB=$(gh api "repos/hashicorp/terraform-provider-helm/contents/go.mod?ref=v$TF_PROVIDER" -q .content 2>/dev/null \
            | base64 -d | awk '$1=="helm.sh/helm/v3" {print $2; exit}')
        [ -n "$HELM_LIB" ] || err "could not resolve the Helm library version of terraform-provider-helm v$TF_PROVIDER"
    fi
    CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/kcx-issue-triage/tf-lint-$HELM_LIB"
    BIN="$CACHE/tf-lint"
    SRC="$SKILL_DIR/scripts/tf-lint/main.go"
    if [ ! -x "$BIN" ] || [ "$SRC" -nt "$BIN" ]; then
        echo "# building tf-lint against helm.sh/helm/v3 $HELM_LIB (one-time, cached in $CACHE) ..."
        mkdir -p "$CACHE"
        cp "$SRC" "$CACHE/main.go"
        ( cd "$CACHE" \
          && { [ -f go.mod ] || go mod init kcx-tf-lint >/dev/null 2>&1; } \
          && go get "helm.sh/helm/v3@$HELM_LIB" >/dev/null 2>&1 \
          && go mod tidy >/dev/null 2>&1 \
          && go build -o tf-lint . ) || err "building tf-lint against helm $HELM_LIB failed (cd $CACHE && go build . to debug)"
    fi
    echo "=== tf-lint: $CHART_DESC — chart $(chart_version "$CHART") ==="
    echo "terraform-provider-helm: ${TF_PROVIDER:+v$TF_PROVIDER }(helm library $HELM_LIB)"
    echo "values: ${VARGS[*]:-(chart defaults)}"
    set +e
    "$BIN" "$CHART" "${VARGS[@]}"
    rc=$?
    set -e
    case "$rc" in
        0) ok "terraform-provider-helm lint passes" ;;
        1) failed "terraform-provider-helm lint fails (\"malformed chart or values\", see above)" ;;
        *) err "tf-lint helper failed to run (exit $rc)" ;;
    esac
    ;;
esac
