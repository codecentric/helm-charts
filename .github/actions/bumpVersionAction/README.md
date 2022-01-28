# Helm chart version bumper

Bumps the version of a helm chart with pythons bump2version. Based on the last commit messages inside the helm chart directory.

## Inputs

### chart

The name of the chart inside the `charts` directory.

## Example usage

The chart to update has to have a `.bumpversion.cfg` in the top level directory. A Sample looks like this.

```
[bumpversion]
current_version = 16.0.6
commit = true
tag = false
message = Bump keycloak chart version: {current_version} → {new_version}

[bumpversion:file:Chart.yaml]
```
The `message` attribute must match the regex `/^Bump {chart_name} chart version:`. The action evaluates all commit messages since the last commit confirming to this regex.

The workflow include looks like this.
```yaml
    - name: Bump Keycloak
      uses: ./.github/actions/bumpVersionAction
      with:
        chart: keycloak
```
