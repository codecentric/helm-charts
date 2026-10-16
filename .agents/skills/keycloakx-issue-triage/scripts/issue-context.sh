#!/usr/bin/env bash
# issue-context.sh — collect everything needed to triage a GitHub issue for
# the keycloakx chart in one read-only pass.
#
# Usage:
#   issue-context.sh <issue-number> [--repo OWNER/NAME]
#
# Prints:
#   * issue metadata, body and all comments
#   * chart / Keycloak / Helm / Kubernetes versions mentioned in the text
#   * the current chart version on origin/master and recent keycloakx tags
#   * possibly related issues and PRs (title keyword search)
#   * PRs that reference the issue number
#
# Read-only: never comments, labels, or otherwise modifies the issue.

set -euo pipefail

REPO="codecentric/helm-charts"
NUM=""

while [ $# -gt 0 ]; do
    case "$1" in
        --repo) REPO="$2"; shift 2 ;;
        -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) NUM="$1"; shift ;;
    esac
done

[ -n "$NUM" ] || { echo "usage: $0 <issue-number> [--repo OWNER/NAME]" >&2; exit 1; }
for b in gh jq git; do
    command -v "$b" >/dev/null 2>&1 || { echo "ERROR: $b not found on PATH" >&2; exit 1; }
done

JSON=$(gh issue view "$NUM" -R "$REPO" \
    --json number,title,state,stateReason,author,labels,createdAt,updatedAt,url,body,comments) \
    || { echo "ERROR: could not fetch issue #$NUM from $REPO (gh auth status?)" >&2; exit 1; }

echo "=== Issue #$NUM ($REPO) ==="
jq -r '"title:   \(.title)
state:   \(.state)\(if (.stateReason // "") != "" then " (" + .stateReason + ")" else "" end)
author:  \(.author.login)
labels:  \([.labels[].name] | join(", ") | if . == "" then "-" else . end)
created: \(.createdAt)   updated: \(.updatedAt)
url:     \(.url)"' <<<"$JSON"

echo
echo "=== Body ==="
jq -r '.body' <<<"$JSON"

echo
echo "=== Comments ($(jq '.comments | length' <<<"$JSON")) ==="
jq -r '.comments[] | "--- \(.author.login) @ \(.createdAt) ---\n\(.body)\n"' <<<"$JSON"

ALL_TEXT=$(jq -r '[.title, .body, (.comments[].body)] | join("\n")' <<<"$JSON")

echo
echo "=== Version hints found in the issue text ==="
# Every version-like token with ~30 chars of context on each side — the agent
# must decide what each one refers to (chart, Keycloak, Helm, Kubernetes ...).
grep -oE '.{0,30}\bv?[0-9]+\.[0-9]+(\.[0-9]+)?\b.{0,30}' <<<"$ALL_TEXT" \
    | grep -viE 'https?://|regex|\^\(' | sort -u | head -25 | sed 's/^/  … /' || true

echo
echo "=== Error/tool fingerprints in the issue text ==="
# Known signatures of chart consumers that are NOT the plain Helm CLI (see
# references/triage-guide.md, "Tool fingerprints"). The agent must still confirm
# them against the reported context.
FP_FOUND=0
if grep -qiF 'malformed chart or values' <<<"$ALL_TEXT"; then
    echo "  'malformed chart or values' -> terraform-provider-helm pre-flight lint"
    echo "     (helm_release with lint=true), NOT the Helm CLI. Reproduce with repro.sh"
    echo "     tf-lint; ask the reporter for the provider version (<= v2.0.x embeds helm"
    echo "     3.3.4: ERROR severity where newer versions only warn) "
    FP_FOUND=1
fi
if grep -qiE 'terraform|helm_release ' <<<"$ALL_TEXT"; then
    echo "  terraform mentioned -> repro.sh tf-lint (--tf-provider); beware set{type=string}"
    echo "     passing booleans as strings"
    FP_FOUND=1
fi
if grep -qiF 'another operation (install/upgrade/rollback) is in progress' <<<"$ALL_TEXT"; then
    echo "  stuck release state (Helm CLI) -> helm rollback; not a chart bug"
    FP_FOUND=1
fi
[ "$FP_FOUND" = 0 ] && echo "  (none recognized — if it still won't reproduce, see tool-fingerprinting in references/triage-guide.md)"

echo
echo "=== Repository state ==="
if git rev-parse --git-dir >/dev/null 2>&1; then
    git fetch origin --tags --prune --quiet 2>/dev/null || echo "(git fetch failed — using local refs)"
    echo "origin/master chart: $(git show origin/master:charts/keycloakx/Chart.yaml 2>/dev/null | grep -E '^(version|appVersion):' | paste -sd' ' -)"
    echo "recent keycloakx tags (usable as --ref for repro.sh):"
    git tag -l 'keycloakx-*' | sort -V | tail -8 | sed 's/^/  /'
    echo "commits on master touching charts/keycloakx since the issue was created:"
    git log origin/master --since="$(jq -r .createdAt <<<"$JSON")" --oneline -- charts/keycloakx | head -20 | sed 's/^/  /' || true
else
    echo "(not inside a git repository)"
fi

echo
echo "=== Timeline: commits, PRs and issues linked to #$NUM ==="
# The timeline is the authoritative source of fixes: commits that mention the
# issue (also from forks / PR branches), cross-references from other issues
# and PRs, and closing events. Each commit is mapped to the first keycloakx
# release that contains it (directly, or via the PR that merged it).
TIMELINE=$(gh api --paginate "repos/$REPO/issues/$NUM/timeline" 2>/dev/null | jq -s 'add // []') || TIMELINE='[]'

first_release() {  # first keycloakx-* tag containing commit $1 (local repo)
    git tag --contains "$1" 2>/dev/null | grep '^keycloakx-' | sort -V | head -1
}
on_master() {
    git merge-base --is-ancestor "$1" origin/master 2>/dev/null && echo yes || echo no
}
describe_commit() {  # sha, repo-of-commit
    local sha="$1" crepo="$2" short="${1:0:7}"
    if git cat-file -e "$sha^{commit}" 2>/dev/null; then
        local rel
        rel=$(first_release "$sha")
        echo "  commit $short ($crepo) — $(git log -1 --format='%s  [%an, %as]' "$sha")"
        echo "    on origin/master: $(on_master "$sha")   first release: ${rel:-none yet}"
        echo "    files: $(git show --format= --name-only "$sha" | paste -sd' ' - | cut -c1-200)"
        return
    fi
    # Not in the local repo (fork / PR branch / squashed away): ask GitHub.
    local info
    info=$(gh api "repos/$crepo/commits/$sha" -q '"\(.commit.message | split("\n")[0])  [\(.commit.author.name), \(.commit.author.date[0:10])]\t\([.files[].filename] | join(" "))"' 2>/dev/null || true)
    echo "  commit $short ($crepo, not in local repo) — ${info%%$'\t'*}"
    [ -n "$info" ] && echo "    files: $(cut -f2 <<<"$info" | cut -c1-200)"
    local prs
    prs=$(gh api "repos/$REPO/commits/$sha/pulls" -q '.[] | "\(.number)\t\(.state)\t\(.merged_at // "-")\t\(.merge_commit_sha // "")\t\(.title)"' 2>/dev/null || true)
    if [ -z "$prs" ]; then
        echo "    no PR in $REPO contains this commit — probably unmerged fork work"
        return
    fi
    local n st merged mc title rel
    while IFS=$'\t' read -r n st merged mc title; do
        if [ "$merged" != "-" ] && [ -n "$mc" ] && git cat-file -e "$mc^{commit}" 2>/dev/null; then
            rel=$(first_release "$mc")
            echo "    via PR #$n (merged $merged as ${mc:0:7}) — $title"
            echo "    on origin/master: $(on_master "$mc")   first release: ${rel:-none yet}"
        else
            echo "    via PR #$n [$st, merged: $merged] — $title"
        fi
    done <<<"$prs"
}

REFS=$(jq -r '.[] | select(.event=="referenced" and .commit_id != null) | "\(.commit_id)\t\(.commit_url // "" | capture("repos/(?<r>[^/]+/[^/]+)/commits").r // "")"' <<<"$TIMELINE" | sort -u)
if [ -n "$REFS" ]; then
    echo "referenced by commits:"
    while IFS=$'\t' read -r sha crepo; do
        describe_commit "$sha" "${crepo:-$REPO}"
    done <<<"$REFS"
else
    echo "referenced by commits: none"
fi

XREFS=$(jq -r '.[] | select(.event=="cross-referenced") | .source.issue | select(. != null) |
    "  #\(.number) [\(if .pull_request then "PR, " + (if .pull_request.merged_at then "merged " + .pull_request.merged_at[0:10] else .state end) else "issue, " + .state end)] \(.title)\(if .repository.full_name != null and .repository.full_name != "'"$REPO"'" then "  (" + .repository.full_name + ")" else "" end)"' <<<"$TIMELINE" | sort -u)
echo "cross-referenced from:"
echo "${XREFS:-  none}"

CLOSES=$(jq -r '.[] | select(.event=="closed" or .event=="reopened") | "  \(.event) by \(.actor.login) @ \(.created_at)\(if .commit_id then " via commit " + .commit_id[0:7] else "" end)"' <<<"$TIMELINE")
[ -n "$CLOSES" ] && { echo "close/reopen events:"; echo "$CLOSES"; }
echo "NOTE: a linked commit/PR is NOT proof of a fix — check that it changes the code path for the reporter's values."

echo
echo "=== PRs mentioning #$NUM in title/body ==="
gh pr list -R "$REPO" --state all --search "$NUM in:body,title" --limit 10 \
    --json number,title,state,url -q '.[] | "  #\(.number) [\(.state)] \(.title)  \(.url)"' 2>/dev/null || true

echo
echo "=== Possibly related issues/PRs (keyword search on title) ==="
# Pick the 3 longest words of the title as search terms.
KEYWORDS=$(jq -r '.title' <<<"$JSON" | tr -c '[:alnum:]-' '\n' | awk 'length > 4' | awk '{print length, $0}' | sort -rn | head -3 | cut -d' ' -f2- | paste -sd' ' -)
if [ -n "$KEYWORDS" ]; then
    echo "search: $KEYWORDS"
    gh search issues --repo "$REPO" --limit 10 --json number,title,state,isPullRequest \
        -q '.[] | "  #\(.number) [\(.state)\(if .isPullRequest then ", PR" else "" end)] \(.title)"' -- $KEYWORDS 2>/dev/null \
        | grep -v "#$NUM " || echo "  (none)"
fi
