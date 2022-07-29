#!/bin/sh

echo "Generating changelog for new version $NEW_VERSION of chart $CHART_NAME"

git-chglog -o charts/$CHART_NAME/CHANGELOG.md --path charts/$CHART_NAME --tag-filter-pattern "$CHART_NAME" --next-tag "$CHART_NAME-$NEW_VERSION"