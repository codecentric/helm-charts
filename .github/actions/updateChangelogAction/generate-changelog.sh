#!/bin/sh

echo "Generating changelog for new version $NEW_VERSION of chart $CHART_NAME"

cd charts/$CHART_NAME

git-chglog -o CHANGELOG.md --tag-filter-pattern "$CHART_NAME" --next-tag "$CHART_NAME-$NEW_VERSION"
