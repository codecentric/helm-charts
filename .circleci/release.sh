#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

: "${CR_TOKEN:?Environment variable CR_TOKEN must be set}"
: "${GIT_REPOSITORY_URL:?Environment variable GIT_REPOSITORY_URL must be set}"
: "${GIT_USERNAME:?Environment variable GIT_USERNAME must be set}"
: "${GIT_EMAIL:?Environment variable GIT_EMAIL must be set}"

readonly REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"

main() {
    pushd "$REPO_ROOT" > /dev/null

    echo "Fetching tags..."
    git fetch --tags

    local latest_tag
    latest_tag=$(find_latest_tag)

    local latest_tag_rev
    latest_tag_rev=$(git rev-parse --verify "$latest_tag")
    echo "$latest_tag_rev $latest_tag (latest tag)"

    local head_rev
    head_rev=$(git rev-parse --verify HEAD)
    echo "$head_rev HEAD"

    if [[ "$latest_tag_rev" == "$head_rev" ]]; then
        echo "No code changes. Nothing to release."
        exit
    fi

    rm -rf .cr-release-packages
    mkdir -p .cr-release-packages

    rm -rf .cr-index
    mkdir -p .cr-index

    echo "Identifying changed charts since tag '$latest_tag'..."

    local changed_charts=()
    readarray -t changed_charts <<< "$(git diff --find-renames --name-only "$latest_tag_rev" -- charts | cut -d '/' -f 2 | uniq)"

    if [[ -n "${changed_charts[*]}" ]]; then
        for chart in "${changed_charts[@]}"; do
            echo "Packaging chart '$chart'..."
            package_chart "charts/$chart"
        done

        release_charts
        update_index
    else
        echo "Nothing to do. No chart changes detected."
    fi

    popd > /dev/null
}

find_latest_tag() {
    if ! git describe --tags --abbrev=0 2> /dev/null; then
        git rev-list --max-parents=0 --first-parent HEAD
    fi
}

package_chart() {
    local chart="$1"
    helm dependency build "$chart"
    helm package "$chart" --destination .cr-release-packages
}

release_charts() {
    cr upload -o codecentric -r helm-charts
}

update_index() {
    cr index -o codecentric -r helm-charts -c https://codecentric.github.io/helm-charts

    git config user.email "$GIT_EMAIL"
    git config user.name "$GIT_USERNAME"

    git checkout gh-pages
    cp --force .cr-index/index.yaml index.yaml
    git add index.yaml
    git commit --message="Update index.yaml" --signoff
    git push "$GIT_REPOSITORY_URL" gh-pages
}

main
