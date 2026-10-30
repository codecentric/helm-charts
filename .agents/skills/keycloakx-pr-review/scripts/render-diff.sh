#!/usr/bin/env bash
# render-diff.sh — static backwards-compatibility check for the keycloakx chart.
#
# Renders the chart at a BASE git ref and a HEAD git ref with several fixed
# values "profiles" and diffs the rendered manifests per profile. Rendered
# output that changes for users whose values did not change is the primary
# signal for backwards-compatibility regressions.
#
# Usage:
#   render-diff.sh BASE_REF HEAD_REF [--values FILE]... [--keep] [--no-ci]
#
#   BASE_REF / HEAD_REF  any git committish (sha, branch, tag, origin/master,
#                        refs/remotes/pr/123). HEAD_REF may be the literal
#                        token WORKTREE to render the current checkout
#                        (uncommitted changes included) as the head side.
#   --values FILE        add an extra profile rendered on both sides (path is
#                        used as the profile name); may be repeated
#   --keep               keep the output directory for inspection
#   --no-ci              skip the "ci" profile (each side's own
#                        charts/keycloakx/ci/h2-values.yaml)
#
# Profiles rendered per side by default:
#   defaults      chart defaults only — what every user gets without overriding
#                 anything. A diff here affects ALL existing users.
#   kitchen-sink  bundled feature-toggle values (ingress, httpRoute,
#                 listenerSet, route, networkPolicy, autoscaling, PDB,
#                 serviceMonitors, dbchecker, rbac, ...) — catches breakage in
#                 optional features.
#   ci            each side's OWN charts/keycloakx/ci/h2-values.yaml — how the
#                 CI install scenario evolves.
#
# Exit code is non-zero only for tooling errors; findings are reported on
# stdout (and encoded in the final RESULT line) for the caller to interpret.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
    sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
}

BASE_REF_ARG=""
HEAD_REF_ARG=""
EXTRA_VALUE_FILES=()
KEEP=0
USE_CI=1

while [ $# -gt 0 ]; do
    case "$1" in
        --values)
            [ $# -ge 2 ] || die "--values requires a file argument"
            [ -f "$2" ] || die "values file not found: $2"
            EXTRA_VALUE_FILES+=("$2")
            shift 2
            ;;
        --keep) KEEP=1; KEEP_TEMP=1; shift ;;
        --no-ci) USE_CI=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *)
            if [ -z "$BASE_REF_ARG" ]; then
                BASE_REF_ARG="$1"
            elif [ -z "$HEAD_REF_ARG" ]; then
                HEAD_REF_ARG="$1"
            else
                die "unexpected argument: $1"
            fi
            shift
            ;;
    esac
done

[ -n "$BASE_REF_ARG" ] && [ -n "$HEAD_REF_ARG" ] || { usage >&2; exit 1; }

require_bin git helm diff

HEAD_FOR_GIT="$HEAD_REF_ARG"
[ "$HEAD_FOR_GIT" = "WORKTREE" ] && HEAD_FOR_GIT="HEAD"

BASE_TIP=$(resolve_commit "$BASE_REF_ARG")
BASE_COMMIT=$(merge_base "$BASE_REF_ARG" "$HEAD_FOR_GIT")

echo "=== keycloakx render-diff ==="
if [ "$BASE_COMMIT" != "$BASE_TIP" ]; then
    echo "base: using merge-base $BASE_COMMIT (branch point of head from $BASE_REF_ARG)"
else
    echo "base: $BASE_COMMIT ($BASE_REF_ARG)"
fi
if [ "$HEAD_REF_ARG" = "WORKTREE" ]; then
    echo "head: WORKTREE (current checkout at $(git rev-parse --short HEAD), uncommitted changes included)"
else
    echo "head: $(resolve_commit "$HEAD_REF_ARG") ($HEAD_REF_ARG)"
fi

resolve_side "$BASE_COMMIT" base
BASE_CHART="$SIDE_DIR"
resolve_side "$HEAD_REF_ARG" head
HEAD_CHART="$SIDE_DIR"

echo "base chart: $(chart_info "$BASE_CHART")"
echo "head chart: $(chart_info "$HEAD_CHART")"
echo

echo "--- changed files (vs merge-base) ---"
git diff --stat "$BASE_COMMIT" "$HEAD_FOR_GIT" -- "$CHART_REL_PATH" || true
if [ "$HEAD_REF_ARG" = "WORKTREE" ]; then
    git status --short -- "$CHART_REL_PATH" || true
fi
echo

OUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/kcx-render-diff-XXXXXX")
register_temp "$OUT_DIR"

CHANGED=0
CHANGED_LINES=0
HEAD_FAILS=0
BASE_FAILS_HEAD_OK=0
BOTH_FAIL=0
PROFILES_TOTAL=0

# render_profile NAME BASE_VALUES HEAD_VALUES — renders both sides (a value of
# "-" means "no values file") and prints the diff status for the profile.
render_profile() {
    local profile="$1" base_vf="$2" head_vf="$3"
    local base_out="$OUT_DIR/${profile//[:\/]/_}.base.yaml"
    local head_out="$OUT_DIR/${profile//[:\/]/_}.head.yaml"
    local base_rc=0 head_rc=0

    local base_args=() head_args=()
    [ "$base_vf" != "-" ] && base_args=(-f "$base_vf")
    [ "$head_vf" != "-" ] && head_args=(-f "$head_vf")

    helm template kcx-review "$BASE_CHART" --namespace kcx-review ${base_args[@]+"${base_args[@]}"} \
        >"$base_out" 2>"$base_out.err" || base_rc=$?
    helm template kcx-review "$HEAD_CHART" --namespace kcx-review ${head_args[@]+"${head_args[@]}"} \
        >"$head_out" 2>"$head_out.err" || head_rc=$?

    PROFILES_TOTAL=$((PROFILES_TOTAL + 1))

    if [ $base_rc -ne 0 ] && [ $head_rc -ne 0 ]; then
        echo "PROFILE $profile: BOTH-SIDES-FAIL (render error on base and head — check whether the values in this profile are valid at all)"
        sed 's/^/    base err: /' "$base_out.err" | head -5
        sed 's/^/    head err: /' "$head_out.err" | head -5
        BOTH_FAIL=$((BOTH_FAIL + 1))
        return
    fi
    if [ $base_rc -ne 0 ]; then
        echo "PROFILE $profile: BASE-FAILS-HEAD-OK (new capability — base chart cannot render these values, head can)"
        sed 's/^/    base err: /' "$base_out.err" | head -5
        BASE_FAILS_HEAD_OK=$((BASE_FAILS_HEAD_OK + 1))
        return
    fi
    if [ $head_rc -ne 0 ]; then
        echo "PROFILE $profile: REGRESSION — head fails to render where base succeeded"
        sed 's/^/    head err: /' "$head_out.err" | head -10
        HEAD_FAILS=$((HEAD_FAILS + 1))
        return
    fi

    local diff_file="$OUT_DIR/${profile//[:\/]/_}.diff"
    if diff -u "$base_out" "$head_out" >"$diff_file"; then
        echo "PROFILE $profile: IDENTICAL"
    else
        local changed
        changed=$(grep -c '^[+-]' "$diff_file")
        echo "PROFILE $profile: CHANGED ($changed diff lines) — full diff below"
        cat "$diff_file"
        echo
        CHANGED=$((CHANGED + 1))
        CHANGED_LINES=$((CHANGED_LINES + changed))
    fi
}

render_profile defaults - -
render_profile kitchen-sink "$KITCHEN_SINK_VALUES" "$KITCHEN_SINK_VALUES"
if [ "$USE_CI" = 1 ] && [ -f "$BASE_CHART/ci/h2-values.yaml" ] && [ -f "$HEAD_CHART/ci/h2-values.yaml" ]; then
    # Each side renders with its OWN ci values file — shows how the CI scenario evolves.
    render_profile ci "$BASE_CHART/ci/h2-values.yaml" "$HEAD_CHART/ci/h2-values.yaml"
fi
for vf in "${EXTRA_VALUE_FILES[@]:-}"; do
    [ -n "$vf" ] || continue
    vfabs="$(cd "$(dirname "$vf")" && pwd)/$(basename "$vf")"
    render_profile "extra:$(basename "$vf")" "$vfabs" "$vfabs"
done

# Lint the head side (errors only) for the two main profiles — informational.
echo "--- helm lint (head side, errors only) ---"
LINT_ERRORS=0
lint_one() {
    local name="$1" vf="$2" lint_out="$OUT_DIR/lint-$1.txt"
    if [ "$vf" = "-" ]; then
        helm lint "$HEAD_CHART" >"$lint_out" 2>&1 || true
    else
        helm lint "$HEAD_CHART" -f "$vf" >"$lint_out" 2>&1 || true
    fi
    if grep -q '^\[ERROR' "$lint_out"; then
        echo "lint [$name]: ERRORS"
        grep '^\[ERROR' "$lint_out" | sed 's/^/    /'
        LINT_ERRORS=$((LINT_ERRORS + 1))
    else
        echo "lint [$name]: ok (warnings: $(grep -c '^\[WARNING' "$lint_out" || true))"
    fi
}
lint_one defaults -
lint_one kitchen-sink "$KITCHEN_SINK_VALUES"
echo

cat <<SUMMARY
=== render-diff summary ===
output dir:       $OUT_DIR
profiles changed: $CHANGED/$PROFILES_TOTAL ($CHANGED_LINES diff lines total)
RESULT: render-diff complete — changed_profiles=$CHANGED changed_lines=$CHANGED_LINES head_render_failures=$HEAD_FAILS base_only_capabilities=$BASE_FAILS_HEAD_OK both_fail=$BOTH_FAIL lint_errors=$LINT_ERRORS
INTERPRETATION:
  defaults CHANGED           -> every existing user is affected; must be intentional and documented (maintainer bumps the chart version at release time)
  kitchen-sink / extra       -> inspect each hunk: additive output for opt-in features is fine, changed pre-existing output is not
  head_render_failures > 0   -> regression (BLOCKER)
SUMMARY

if [ "$KEEP" = 1 ]; then
    KEEP_TEMP=1
fi
