# Changelog

<a name="keycloakx-1.5.0"></a>
## [keycloakx-1.5.0] - 2022-07-29
- Bump keycloakx chart version: 1.4.2 → 1.5.0
- feat: add namespace attribute in keycloakx objects ([#584](https://github.com/codecentric/helm-charts/issues/584))

<a name="keycloakx-1.4.2"></a>
## [keycloakx-1.4.2] - 2022-07-25
- Bump keycloakx chart version: 1.4.1 → 1.4.2
- fix: correct fallback when no existingSecret ([#623](https://github.com/codecentric/helm-charts/issues/623))

<a name="keycloakx-1.4.1"></a>
## [keycloakx-1.4.1] - 2022-07-15
- Bump keycloakx chart version: 1.4.0 → 1.4.1
- [keycloakx] improve documentation for existing secret ([#621](https://github.com/codecentric/helm-charts/issues/621))
- use existing secret for  keycloakx database password ([#601](https://github.com/codecentric/helm-charts/issues/601))
- add automountServiceAccountToken parameter ([#596](https://github.com/codecentric/helm-charts/issues/596))
- Bump keycloakx chart version: 1.3.2 → 1.4.0
- improve command and args management in order to avoid an empty array if not needed ([#597](https://github.com/codecentric/helm-charts/issues/597))
- [keycloakx] Major version upgrade to Keycloak 18.0.0 ([#591](https://github.com/codecentric/helm-charts/issues/591)) ([#592](https://github.com/codecentric/helm-charts/issues/592))
- chore: Use tpl for relative path

<a name="keycloakx-1.3.2"></a>
## [keycloakx-1.3.2] - 2022-05-06
- Bump keycloakx chart version: 1.3.1 → 1.3.2
- Fix typo in values.yaml ([#585](https://github.com/codecentric/helm-charts/issues/585))

<a name="keycloakx-1.3.1"></a>
## [keycloakx-1.3.1] - 2022-04-22
- Bump keycloakx chart version: 1.3.0 → 1.3.1
- fix ClusterRole and ClusterRoleBinding names. Need if multiple namespaces

<a name="keycloakx-1.3.0"></a>
## [keycloakx-1.3.0] - 2022-04-16
- Bump keycloakx chart version: 1.2.0 → 1.3.0
- chore: add relativePath at values.scheme, use tpl at ingress, serviceMonitor path
- feature: use http.relativePath instead hardcoded '/auth', correct README

<a name="keycloakx-1.2.0"></a>
## [keycloakx-1.2.0] - 2022-04-14
- Bump keycloakx chart version: 1.1.1 → 1.2.0
- feat: make test deletion policy configurable

<a name="keycloakx-1.1.1"></a>
## [keycloakx-1.1.1] - 2022-04-11
- Bump keycloakx chart version: 1.1.0 → 1.1.1
- Fix typo in KC_DB_URL_DATABASE environment variable

<a name="keycloakx-1.1.0"></a>
## [keycloakx-1.1.0] - 2022-04-09
- Bump keycloakx chart version: 1.0.1 → 1.1.0
- feature: Add support for kube_ping clustering
- chore: Revise start command in readme
- chore: Add missing documentation for TLS config for keycloak ingress and keycloak-console
- Add some helm guidance to keycloakx postgres example
- Simplify commands for keycloakx docker example
- Fix readme keycloakx postgres

<a name="keycloakx-1.0.1"></a>
## keycloakx-1.0.1 - 2022-04-08
- Bump keycloakx chart version: 1.0.0 → 1.0.1
- Major Keycloak.X Update to version 17.0.1
- [keycloakx] KeycloakX support

[Unreleased]: https://github.com/codecentric/helm-charts/compare/keycloakx-8.0.0...HEAD
[keycloakx-8.0.0]: https://github.com/codecentric/helm-charts/compare/keycloakx-1.5.0...keycloakx-8.0.0
[keycloakx-1.5.0]: https://github.com/codecentric/helm-charts/compare/keycloakx-1.4.2...keycloakx-1.5.0
[keycloakx-1.4.2]: https://github.com/codecentric/helm-charts/compare/keycloakx-1.4.1...keycloakx-1.4.2
[keycloakx-1.4.1]: https://github.com/codecentric/helm-charts/compare/keycloakx-1.3.2...keycloakx-1.4.1
[keycloakx-1.3.2]: https://github.com/codecentric/helm-charts/compare/keycloakx-1.3.1...keycloakx-1.3.2
[keycloakx-1.3.1]: https://github.com/codecentric/helm-charts/compare/keycloakx-1.3.0...keycloakx-1.3.1
[keycloakx-1.3.0]: https://github.com/codecentric/helm-charts/compare/keycloakx-1.2.0...keycloakx-1.3.0
[keycloakx-1.2.0]: https://github.com/codecentric/helm-charts/compare/keycloakx-1.1.1...keycloakx-1.2.0
[keycloakx-1.1.1]: https://github.com/codecentric/helm-charts/compare/keycloakx-1.1.0...keycloakx-1.1.1
[keycloakx-1.1.0]: https://github.com/codecentric/helm-charts/compare/keycloakx-1.0.1...keycloakx-1.1.0
