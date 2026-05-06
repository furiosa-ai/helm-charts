# FuriosaAI Cloud Native Toolkit Helm Charts

## Usage

[Helm](https://helm.sh) must be installed to use the charts.
Please refer to Helm's [documentation](https://helm.sh/docs/) to get started.



```console
helm repo add furiosa https://furiosa-ai.github.io/helm-charts
```
You can then run `helm search repo furiosa` to see the charts.

### Releasing

1. Open a PR bumping the relevant `Chart.yaml` `version` (and `appVersion`) fields. Get it reviewed and merged into `main`.
2. On the merged commit, create a GitHub Release: tag = the calver (e.g., `2026.2.0`), target = `main`, "Set as the latest release", **not** prerelease, **not** draft. Release notes are free-form.
3. The `Release Charts` workflow runs automatically and packages every chart whose `Chart.yaml: version` matches the release tag, attaches the `.tgz` files to the Release as assets, and updates `gh-pages/index.yaml`.
4. If the workflow fails, re-trigger it via Actions → `Release Charts` → "Run workflow" → enter `tag: 2026.2.0`.

For a single-chart hotfix, bump only that chart and use that chart's new version as the release tag (e.g., `2026.2.1`).

## Known Issues

### furiosa-feature-discovery
- If you’re using a Kubernetes cluster with a version lower than v1.24, installing the furiosa-feature-discovery Helm chart may fail due to a resource version issue with its dependency chart node-feature-discovery.
  To work around this, manually install an older version of node-feature-discovery on your cluster.
  Then, in the [values.yaml](charts/furiosa-feature-discovery/values.yaml) file of the furiosa-feature-discovery chart, set `node-feature-discovery.enabled` to `false` to prevent automatic installation.



## License

```
Copyright 2023 FuriosaAI, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
