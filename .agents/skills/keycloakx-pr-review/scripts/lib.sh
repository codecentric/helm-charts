#!/usr/bin/env bash
# Shared helpers for the keycloakx-pr-review skill scripts.
# Sourced by render-diff.sh and k3d-live-test.sh — not executable on its own.

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KITCHEN_SINK_VALUES="$SKILL_DIR/values/kitchen-sink.yaml"
LIVE_VALUES="$SKILL_DIR/values/live-upgrade.yaml"

# Path of the chart inside the repository (relative to the git root).
CHART_REL_PATH="charts/keycloakx"

CLEANUP_PATHS=()
CLEANUP_CMDS=()
KEEP_TEMP=0

die() {
    echo "ERROR: $*" >&2
    exit 1
}

require_bin() {
    local b
    for b in "$@"; do
        command -v "$b" >/dev/null 2>&1 || die "required binary not found on PATH: $b"
    done
}

git_root() {
    git rev-parse --show-toplevel 2>/dev/null || die "not inside a git repository — run this script from within the helm-charts repository"
}

resolve_commit() {
    git rev-parse --verify -q "$1^{commit}" >/dev/null 2>&1 || die "not a valid git ref: $1"
    git rev-parse "$1^{commit}"
}

# merge_base BASE_REF HEAD_REF — prints the merge-base commit of the two refs,
# falling back to BASE_REF itself when no merge-base exists (unrelated histories).
merge_base() {
    local mb
    mb=$(git merge-base "$(resolve_commit "$1")" "$(resolve_commit "$2")" 2>/dev/null || true)
    if [ -n "$mb" ]; then
        echo "$mb"
    else
        resolve_commit "$1"
    fi
}

register_temp() {
    CLEANUP_PATHS+=("$1")
}

# register_cleanup CMD — run CMD (a string, evaluated on exit) during cleanup.
register_cleanup() {
    CLEANUP_CMDS+=("$1")
}

cleanup() {
    local c
    for c in "${CLEANUP_CMDS[@]:-}"; do
        [ -n "$c" ] && eval "$c" >/dev/null 2>&1 || true
    done
    if [ "$KEEP_TEMP" = 1 ]; then
        if [ "${#CLEANUP_PATHS[@]}" -gt 0 ]; then
            echo "# temp artifacts kept for inspection:"
            local p
            for p in "${CLEANUP_PATHS[@]}"; do
                echo "#   $p"
            done
        fi
    else
        local p
        for p in "${CLEANUP_PATHS[@]:-}"; do
            [ -n "$p" ] && rm -rf "$p"
        done
    fi
    git worktree prune >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# new_worktree REF LABEL — creates a detached git worktree for REF in a fresh
# temp dir and sets WORKTREE_DIR to the worktree path. The worktree (and its
# temp dir) is removed on exit. NOTE: must NOT be called inside a command
# substitution — registration of the temp dir happens via a global variable.
WORKTREE_DIR=""
new_worktree() {
    local ref="$1" label="$2" root
    root=$(mktemp -d "${TMPDIR:-/tmp}/kcx-review-${label}-XXXXXX") || die "mktemp failed"
    git worktree add --detach "$root/chart" "$(resolve_commit "$ref")" >/dev/null 2>&1 || die "git worktree add failed for ref: $ref"
    register_temp "$root"
    WORKTREE_DIR="$root/chart"
}

SIDE_DIR=""

# resolve_side REF LABEL — sets SIDE_DIR to the keycloakx chart directory for
# the given ref. REF may be the literal token WORKTREE, in which case the
# current checkout is used (uncommitted changes included).
resolve_side() {
    local ref="$1" label="$2"
    if [ "$ref" = "WORKTREE" ]; then
        SIDE_DIR="$(git_root)/$CHART_REL_PATH"
    else
        new_worktree "$ref" "$label"
        SIDE_DIR="$WORKTREE_DIR/$CHART_REL_PATH"
    fi
    [ -d "$SIDE_DIR" ] || die "chart '$CHART_REL_PATH' not found in $ref — does the PR touch the keycloakx chart?"
}

chart_info() {
    helm show chart "$1" 2>/dev/null | grep -E '^(name|version|appVersion):' | cut -d' ' -f1- | paste -sd' ' -
}
