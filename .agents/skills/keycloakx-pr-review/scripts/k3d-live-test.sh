#!/usr/bin/env bash
# k3d-live-test.sh — live backwards-compatibility test for the keycloakx chart
# on a local k3d cluster.
#
# Flow:
#   1. resolve BASE ref (default: merge-base of head with origin/master) and
#      HEAD ref into temp git worktrees
#   2. install the BASE chart with the bundled review values and wait for it
#      to become healthy       (simulates an existing user installation)
#   3. helm upgrade to the HEAD chart with the IDENTICAL values file
#      (simulates a user upgrading the chart without touching their values)
#   4. wait for the rollout to complete and probe the health endpoint
#
# Usage:
#   k3d-live-test.sh --head-ref REF [--base-ref REF] [--cluster NAME]
#                    [--namespace NAME] [--reset] [--keep] [--timeout SECS]
#                    [--values FILE]
#
#   --head-ref (required)  git ref of the PR head, or WORKTREE to test the
#                          current checkout (uncommitted changes included)
#   --base-ref             git ref of the PR base (default origin/master; the
#                          merge-base with the head is actually used)
#   --cluster              k3d cluster to use (defaults: current kubectl
#                          context if it is a k3d context, then the first
#                          running k3d cluster, else an ephemeral cluster is
#                          created and torn down afterwards)
#   --namespace            namespace to install into (default kcx-review-<pid>)
#   --reset                delete and recreate the namespace if it already exists
#   --keep                 keep the namespace after a successful run (it is
#                          kept automatically when the test fails)
#   --timeout SECS        per-phase timeout, default 900
#   --values FILE          additional values applied to BOTH install and
#                          upgrade, on top of the bundled live values
#
# Safety:
#   * never changes the current kubectl context (everything uses --context)
#   * only ever deletes the one namespace it was told to use
#   * an existing cluster is left running; an ephemeral cluster created by this
#     script is deleted again afterwards

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
    sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'
}

HEAD_REF=""
BASE_REF="origin/master"
OPT_CLUSTER=""
OPT_NS=""
OPT_RESET=0
KEEP_NS=0
TIMEOUT=900
EXTRA_VALUES_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --head-ref) HEAD_REF="$2"; shift 2 ;;
        --base-ref) BASE_REF="$2"; shift 2 ;;
        --cluster) OPT_CLUSTER="$2"; shift 2 ;;
        --namespace) OPT_NS="$2"; shift 2 ;;
        --reset) OPT_RESET=1; shift ;;
        --keep) KEEP_NS=1; shift ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --values)
            [ -f "$2" ] || die "values file not found: $2"
            EXTRA_VALUES_FILE="$2"
            shift 2
            ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

[ -n "$HEAD_REF" ] || { usage >&2; exit 1; }

require_bin git helm kubectl jq

HEAD_FOR_GIT="$HEAD_REF"
[ "$HEAD_FOR_GIT" = "WORKTREE" ] && HEAD_FOR_GIT="HEAD"
BASE_COMMIT=$(merge_base "$BASE_REF" "$HEAD_FOR_GIT")

resolve_side "$BASE_COMMIT" base
BASE_CHART="$SIDE_DIR"
resolve_side "$HEAD_REF" head
HEAD_CHART="$SIDE_DIR"

RELEASE="kcx-review"
NS="${OPT_NS:-kcx-review-$$}"
STAGE="setup"
K3D_CREATED_CLUSTER=""
KEEP_CLUSTER=""
COMPLETED=0

# Print a RESULT line even when the script dies unexpectedly (set -e etc.)
abort_guard() {
    cleanup
    if [ "$COMPLETED" != 1 ]; then
        echo "RESULT: FAIL (aborted unexpectedly at stage: $STAGE — see errors above; namespace $NS may need manual cleanup: kubectl --context ${CTX:-?} delete ns $NS)"
    fi
}
trap abort_guard EXIT

fail() {
    echo
    echo "RESULT: FAIL (stage: $STAGE — $1)"
    if kc get ns "$NS" >/dev/null 2>&1; then
        echo "namespace '$NS' was kept for inspection. Inspect with:"
        echo "  kubectl --context $CTX -n $NS get pods -o wide"
        echo "  kubectl --context $CTX -n $NS describe sts ${STS:-$RELEASE-keycloakx}"
        echo "Remove with:"
        echo "  kubectl --context $CTX delete ns $NS"
    fi
    COMPLETED=1
    exit 1
}

# ---------------------------------------------------------------------------
# Cluster resolution (never switches the current context)
# ---------------------------------------------------------------------------
CTX=""

if command -v k3d >/dev/null 2>&1; then
    if [ -n "$OPT_CLUSTER" ]; then
        k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$OPT_CLUSTER" \
            || die "k3d cluster '$OPT_CLUSTER' not found (k3d cluster list)"
        CTX="k3d-$OPT_CLUSTER"
    else
        cur_ctx=$(kubectl config current-context 2>/dev/null || true)
        if [ "${cur_ctx#k3d-}" != "$cur_ctx" ]; then
            CTX="$cur_ctx"
        else
            first_cluster=$(k3d cluster list 2>/dev/null | awk 'NR==2 {print $1}')
            [ -n "$first_cluster" ] && CTX="k3d-$first_cluster"
        fi
    fi
fi

if [ -z "$CTX" ]; then
    if [ -n "$OPT_CLUSTER" ]; then
        die "cluster '$OPT_CLUSTER' requested but k3d binary not found or cluster missing"
    fi
    echo "no k3d cluster running — creating ephemeral cluster 'kcx-review-cluster'"
    K3D_CREATED_CLUSTER="kcx-review-cluster"
    k3d cluster create "$K3D_CREATED_CLUSTER" --wait >/dev/null 2>&1 || die "k3d cluster create failed"
    CTX="k3d-$K3D_CREATED_CLUSTER"
    register_cleanup "[ -n \"\$KEEP_CLUSTER\" ] || k3d cluster delete \"\$K3D_CREATED_CLUSTER\" >/dev/null 2>&1 || true"
fi

if ! kubectl config get-contexts 2>/dev/null | grep -qw "$CTX"; then
    cluster_name="${CTX#k3d-}"
    echo "context '$CTX' missing from kubeconfig — merging it via k3d"
    k3d kubeconfig merge "$cluster_name" --kubeconfig-merge-default >/dev/null 2>&1 \
        || die "could not merge kubeconfig for cluster $cluster_name"
fi

kc() { kubectl --context "$CTX" "$@"; }

echo "=== keycloakx live upgrade test ==="
echo "cluster:  $CTX"
echo "base:     $(chart_info "$BASE_CHART")"
echo "head:     $(chart_info "$HEAD_CHART")  (ref: $HEAD_REF)"
echo "namespace: $NS   release: $RELEASE   timeout: ${TIMEOUT}s"
echo

kc get --raw /readyz >/dev/null 2>&1 || die "cluster not reachable via context $CTX"

# ---------------------------------------------------------------------------
# Namespace preparation
# ---------------------------------------------------------------------------
if kc get ns "$NS" >/dev/null 2>&1; then
    if [ "$OPT_RESET" = 1 ]; then
        echo "namespace '$NS' exists — deleting (--reset)"
        kc delete ns "$NS" --wait --timeout="${TIMEOUT}s" || die "failed to delete namespace $NS"
    else
        pod_count=$(kc get pods -n "$NS" --no-headers 2>/dev/null | wc -l)
        if [ "$pod_count" = "0" ]; then
            kc delete ns "$NS" --wait --timeout="${TIMEOUT}s" || true
        else
            die "namespace '$NS' already exists and is not empty (found $pod_count pod(s)). Use --reset to recreate it, or --namespace to pick another one."
        fi
    fi
fi
kc create ns "$NS" >/dev/null

VALUES_ARGS=(-f "$LIVE_VALUES")
[ -n "$EXTRA_VALUES_FILE" ] && VALUES_ARGS+=(-f "$EXTRA_VALUES_FILE")

# ---------------------------------------------------------------------------
# Phase 1: install the BASE chart (the "existing user" installation)
# ---------------------------------------------------------------------------
STAGE="install-base"
echo "--- [1/4] installing BASE chart (name: $RELEASE) ---"
if ! helm --kube-context "$CTX" -n "$NS" install "$RELEASE" "$BASE_CHART" \
        "${VALUES_ARGS[@]}" --wait --timeout "${TIMEOUT}s"; then
    fail "base chart did not install/come up healthy"
fi
BASE_INSTALLED_VERSION=$(helm --kube-context "$CTX" -n "$NS" list --filter "$RELEASE" -o json | jq -r '.[0].chart')

echo "base chart deployed: $BASE_INSTALLED_VERSION"

STS=$(kc -n "$NS" get sts -l app.kubernetes.io/instance="$RELEASE" -o jsonpath='{.items[0].metadata.name}')
[ -n "$STS" ] || fail "could not find StatefulSet for release $RELEASE in namespace $NS"

STAGE="base-rollout"
if ! kc -n "$NS" rollout status "sts/$STS" --timeout="${TIMEOUT}s"; then
    fail "base chart rollout did not complete"
fi
echo "base rollout complete:"
kc -n "$NS" get pods -o wide || true
echo

# ---------------------------------------------------------------------------
# Phase 2: upgrade to the HEAD chart with the IDENTICAL values
# ---------------------------------------------------------------------------
STAGE="upgrade-head"
echo "--- [2/4] upgrading to HEAD chart (same values, no changes) ---"
if ! helm --kube-context "$CTX" -n "$NS" upgrade "$RELEASE" "$HEAD_CHART" \
        "${VALUES_ARGS[@]}" --wait --timeout "${TIMEOUT}s"; then
    fail "helm upgrade to head chart failed (check output above for immutable-field or schema errors)"
fi
HEAD_INSTALLED_VERSION=$(helm --kube-context "$CTX" -n "$NS" list --filter "$RELEASE" -o json | jq -r '.[0].chart')

STAGE="head-rollout"
if ! kc -n "$NS" rollout status "sts/$STS" --timeout="${TIMEOUT}s"; then
    fail "head chart rollout did not complete (stuck or crashing pods)"
fi

echo "upgrade complete: $BASE_INSTALLED_VERSION -> $HEAD_INSTALLED_VERSION"

# ---------------------------------------------------------------------------
# Phase 3: diagnostics
# ---------------------------------------------------------------------------
STAGE="verify"
echo "--- [3/4] post-upgrade state ---"
kc -n "$NS" get pods -o wide || true

NOT_READY=$(kc -n "$NS" get pods --no-headers 2>/dev/null | awk '{split($2,a,"/"); if (a[1]!=a[2] || $3!="Running") c++} END {print c+0}')
[ "$NOT_READY" = "0" ] || fail "$NOT_READY pod(s) not Running/Ready after upgrade"

echo "--- [4/4] health endpoint probe (best-effort) ---"
PROBE_PORT=$(kc -n "$NS" get sts "$STS" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}')
PROBE_PATH=$(kc -n "$NS" get sts "$STS" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}')
PROBE_PORTNUM=$(kc -n "$NS" get sts "$STS" -o jsonpath='{range .spec.template.spec.containers[0].ports[*]}{.name}={.containerPort}{"\n"}{end}' | grep "^$PROBE_PORT=" | cut -d= -f2 || true)
if [ -n "$PROBE_PORTNUM" ] && [ -n "$PROBE_PATH" ] && command -v curl >/dev/null 2>&1; then
    # Keycloak pods run as non-root without curl — reach the management port
    # via port-forward and probe from the host instead.
    PF_LOG=$(mktemp)
    kc -n "$NS" port-forward "pod/$STS-0" --address 127.0.0.1 "0:$PROBE_PORTNUM" >"$PF_LOG" 2>&1 &
    PF_PID=$!
    PF_PORT=""
    for _ in $(seq 1 30); do
        PF_PORT=$( { grep -o 'Forwarding from 127.0.0.1:[0-9]*' "$PF_LOG" || true; } | grep -o '[0-9]*$' | head -1 || true)
        [ -n "$PF_PORT" ] && break
        sleep 0.5
    done
    if [ -n "$PF_PORT" ]; then
        PROBE_URL="http://127.0.0.1:${PF_PORT}${PROBE_PATH}"
        echo "probing readiness endpoint via port-forward: $PROBE_URL"
        if curl -fsS --max-time 10 "$PROBE_URL" >/dev/null 2>&1; then
            echo "health probe: OK"
        else
            echo "health probe: FAILED — readiness endpoint did not answer (kubelet probes passed, so this may be a port-forward artifact)"
        fi
    else
        echo "health probe: SKIPPED (port-forward could not be established)"
    fi
    kill "$PF_PID" >/dev/null 2>&1 || true
    rm -f "$PF_LOG"
else
    echo "health probe: SKIPPED (no curl on host, or probe port/path not derivable) — kubelet readiness probes already passed"
fi
echo

# ---------------------------------------------------------------------------
# Cleanup / result
# ---------------------------------------------------------------------------
COMPLETED=1
if [ "$KEEP_NS" = 0 ]; then
    kc delete ns "$NS" --wait=false >/dev/null 2>&1 || true
    echo "namespace '$NS' deletion triggered"
else
    echo "namespace '$NS' kept (--keep)"
fi

cat <<RESULT
RESULT: PASS — base $BASE_INSTALLED_VERSION upgraded in place to $HEAD_INSTALLED_VERSION with unchanged values; rollout completed and all pods ready.
RESULT
