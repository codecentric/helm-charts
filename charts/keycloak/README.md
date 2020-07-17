# Keycloak

[Keycloak](http://www.keycloak.org/) is an open source identity and access management for modern applications and services.

## TL;DR;

```console
$ helm install keycloak codecentric/keycloak
```

## Introduction

This chart bootstraps a [Keycloak](http://www.keycloak.org/) StatefulSet on a [Kubernetes](https://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.
It provisions a fully featured Keycloak installation.
For more information on Keycloak and its capabilities, see its [documentation](http://www.keycloak.org/documentation.html).

## Prerequisites Details

The chart has an optional dependency on the [PostgreSQL](https://github.com/bitnami/charts/tree/master/bitnami/postgresql) chart.
By default, the PostgreSQL chart requires PV support on underlying infrastructure (may be disabled).

## Installing the Chart

To install the chart with the release name `keycloak`:

```console
$ helm install keycloak codecentric/keycloak
```

## Uninstalling the Chart

To uninstall the `keycloak` deployment:

```console
$ helm uninstall keycloak
```

## Configuration

The following table lists the configurable parameters of the Keycloak chart and their default values.

| Parameter | Description | Default |
|---|---|---|
| `fullnameOverride` | Optionally override the fully qualified name | `""` |
| `nameOverride` | Optionally override the name | `""` |
| `replicas` | The number of replicas to create | `1` |
| `image.repository` | The Keycloak image repository | `docker.io/jboss/keycloak` |
| `image.tag` | Overrides the Keycloak image tag whose default is the chart version | `""` |
| `image.pullPolicy` | The Keycloak image pull policy | `IfNotPresent` |
| `imagePullSecrets` | Image pull secrets for the Pod | `` |
| `hostAliases` | Mapping between IPs and hostnames that will be injected as entries in the Pod's hosts files | `[]` |
| `enableServiceLinks` | Indicates whether information about services should be injected into Pod's environment variables, matching the syntax of Docker links | `true` |
| `podManagementPolicy` | Pod management policy. One of `Parallel` or `OrderedReady` | `Parallel` |
| `restartPolicy` | Pod restart policy. One of `Always`, `OnFailure`, or `Never` | `Always` |
| `serviceAccount.create` | Specifies whether a ServiceAccount should be created | `true` |
| `serviceAccount.name` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template | `""` |
| `serviceAccount.annotations` | Additional annotations for the ServiceAccount | `{}` |
| `serviceAccount.labels` | Additional labels for the ServiceAccount | `{}` |
| `serviceAccount.imagePullSecrets` | Image pull secrets that are attached to the ServiceAccount | `[]` |
| `podSecurityContext` | SecurityContext for the entire Pod. Every container running in the Pod will inherit this SecurityContext. This might be relevant when other components of the environment inject additional containers into running Pods (service meshes are the most prominent example for this) | `{"fsGroup":1000}` |
| `securityContext` | SecurityContext for the Keycloak container | `{"runAsNonRoot":true,"runAsUser":1000}` |
| `extraInitContainers` | Additional init containers, e. g. for providing custom themes | `[]` |
| `extraContainers` | Additional sidecar containers, e. g. for a database proxy, such as Google's cloudsql-proxy | `[]` |
| `lifecycleHooks` | Lifecycle hooks for the Keycloak container | `{}` |
| `terminationGracePeriodSeconds` | Termination grace period in seconds for Keycloak shutdown. Clusters with a large cache might need to extend this to give Infinispan more time to rebalance | `60` |
| `clusterDomain` | The internal Kubernetes cluster domain | `cluster.local` |
| `command` | # Overrides the default entrypoint of the Keycloak container | `[]` |
| `args` | # Overrides the default args for the Keycloak container | `[]` |
| `extraEnv` | Additional environment variables for Keycloak | `[]` |
| `priorityClassName` | Pod priority class name | `""` |
| `affinity` | Pod affinity | `{}` |
| `nodeSelector` | Node labels for Pod assignment | `{}` |
| `tolerations` | Node taints to tolerate | `[]` |
| `podLabels` | Additional Pod labels | `{}` |
| `podAnnotations` | Additional Pod annotations | `{}` |
| `livenessProbe` | Liveness probe configuration | `{"httpGet":{"path":"/auth","port":"http"},"initialDelaySeconds":300,"timeoutSeconds":5}` |
| `readinessProbe` | Readiness probe configuration | `{"httpGet":{"path":"/auth/realms/master","port":"http"},"initialDelaySeconds":30,"timeoutSeconds":1}` |
| `resources` | Pod resource requests and limits | `{}` |
| `startupScripts` | Startup scripts to run before Keycloak starts up | `{"keycloak.cli":"{{- .Files.Get \"scripts/keycloak.cli\" | nindent 2 }}\n"}` |
| `extraVolumes` | Add additional volumes, e. g. for custom themes | `[]` |
| `extraVolumeMounts` | Add additional volumes mounts, e. g. for custom themes | `[]` |
| `extraPorts` | Add additional ports, e. g. for admin console or exposing JGroups ports | `[]` |
| `podDisruptionBudget` | Pod disruption budget | `{}` |
| `statefulsetAnnotations` | Annotations for the StatefulSet | `{}` |
| `statefulsetLabels` | Additional labels for the StatefulSet | `{}` |
| `secrets` | Configuration for secrets that should be created | `[]` |
| `service.annotations` | Annotations for headless and HTTP Services | `{}` |
| `service.labels` | Additional labels for headless and HTTP Services | `{}` |
| `service.type` | The Service type | `ClusterIP` |
| `service.nodePort` | Optional static port assignment for Service type NodePort. | `""` |
| `service.httpPort` | The http Service port | `80` |
| `service.httpNodePort` | The HTTP Service node port if type is NodePort | `""` |
| `service.httpsPort` | The HTTPS Service port | `8443` |
| `service.httpsNodePort` | The HTTPS Service node port if type is NodePort | `""` |
| `service.extraPorts` | Additional Service ports, e. g. for custom admin console | `[]` |
| `ingress.enabled` | If `true`, an Ingress is created | `false` |
| `ingress.rules` | List of Ingress Ingress rule | see below |
| `ingress.rules[0].host` | Host for the Ingress rule | `keycloak.example.com` |
| `ingress.rules[0].paths` | Paths for the Ingress rule | `[/]` |
| `ingress.servicePort` | The Service port targeted by the Ingress | `http` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.labels` | Additional Ingress labels | `{}` |
| `ingress.tls` | TLS configuration | see below |
| `ingress.tls[0].hosts` | List of TLS hosts | `[keycloak.example.com]` |
| `ingress.tls[0].secretName` | Name of the TLS secret | `keycloak-tls` |
| `route.enabled` | If `true`, an OpenShift Route is created | `false` |
| `route.path` | Path for the Route | `/` |
| `route.annotations` | Route annotations | `{}` |
| `route.labels` | Additional Route labels | `{}` |
| `route.host` | Host name for the Route | `""` |
| `route.tls.enabled` | If `true`, TLS is enabled for the Route | `true` |
| `route.tls.insecureEdgeTerminationPolicy` | Insecure edge termination policy of the Route. Can be `None`, `Redirect`, or `Allow` | `Redirect` |
| `route.tls.termination` | TLS termination of the route. Can be `edge`, `passthrough`, or `reencrypt` | `edge` |
| `pgchecker.image.repository` | Docker image used to check Postgresql readiness at startup | `docker.io/busybox` |
| `pgchecker.image.tag` | Image tag for the pgchecker image | `1.32` |
| `pgchecker.image.pullPolicy` | Image pull policy for the pgchecker image | `IfNotPresent` |
| `pgchecker.securityContext` | SecurityContext for the pgchecker container | `{"allowPrivilegeEscalation":false,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000}` |
| `pgchecker.resources` | Resource requests and limits for the pgchecker container | `{"limits":{"cpu":"10m","memory":"16Mi"},"requests":{"cpu":"10m","memory":"16Mi"}}` |
| `postgresql.enabled` | If `true`, the Postgresql dependency is enabled | `true` |
| `postgresql.postgresqlUsername` | PostgreSQL User to create | `keycloak` |
| `postgresql.postgresqlPassword` | PostgreSQL Password for the new user | `keycloak` |
| `postgresql.postgresqlDatabase` | PostgreSQL Database to create | `keycloak` |
| `prometheusOperator.enabled` | If `true`, a ServiceMonitor resource for the prometheus-operator is created | `false` |
| `prometheusOperator.serviceMonitor.namespace` | Optionally sets a target namespace in which to deploy the ServiceMonitor resource | `""` |
| `prometheusOperator.serviceMonitor.annotations` | Annotations for the ServiceMonitor | `{}` |
| `prometheusOperator.serviceMonitor.labels` | Additional labels for the ServiceMonitor | `{}` |
| `prometheusOperator.serviceMonitor.interval` | Interval at which Prometheus scrapes metrics | `10s` |
| `prometheusOperator.serviceMonitor.scrapeTimeout` | Timeout for scraping | `10s` |
| `prometheusOperator.serviceMonitor.path` | The path at which metrics are served | `/auth/realms/master/metrics` |
| `prometheusOperator.serviceMonitor.port` | The Service port at which metrics are served | `http` |
| `prometheusOperator.prometheusRule.enabled` | If `true`, a PrometheusRule resource for the prometheus-operator is created | `false` |
| `prometheusOperator.prometheusRule.annotations` | Annotations for the PrometheusRule | `{}` |
| `prometheusOperator.prometheusRule.labels` | Additional labels for the PrometheusRule | `{}` |
| `prometheusOperator.prometheusRule.rules` | List of rules for Prometheus | `` |
| `test.enabled` | If `true`, test resources are created | `false` |
| `test.image.repository` | The image for the test Pod | `docker.io/unguiculus/docker-python3-phantomjs-selenium` |
| `test.image.tag` | The tag for the test Pod image | `v1` |
| `test.image.pullPolicy` | The image pull policy for the test Pod image | `IfNotPresent` |
| `test.podSecurityContext` | SecurityContext for the entire test Pod | `{"fsGroup":1000}` |
| `test.securityContext` | SecurityContext for the test container | `{"runAsNonRoot":true,"runAsUser":1000}` |


Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example:

```console
$ helm install keycloak codecentric/keycloak -n keycloak --version=9.0.0 --set replicas=1
```

Alternatively, a YAML file that specifies the values for the parameters can be provided while
installing the chart. For example:

```console
$ helm install keycloak codecentric/keycloak -n keycloak --version=9.0.0 --values values.yaml
```

The chart offers great flexibility.
Out of the box, it works with the official Keycloak Docker image but can be configured to work with any other custom image as well.

### Usage of the `tpl` Function

The `tpl` function allows us to pass string values from `values.yaml` through the templating engine.
It is used for the following values:

* `keycloak.extraInitContainers`
* `keycloak.extraContainers`
* `keycloak.extraEnv`
* `keycloak.affinity`
* `keycloak.extraVolumeMounts`
* `keycloak.extraVolumes`
* `keycloak.livenessProbe`
* `keycloak.readinessProbe`

It is important that these values be configured as strings.
Otherwise, installation will fail. See example for Google Cloud Proxy or default affinity configuration in `values.yaml`.

### Database Setup

By default, Keycloak uses an embedded H2 database.
This is only suitable for testing purposes.
All data is lost when Keycloak is shut down.
Optionally, the [PostgreSQL](https://github.com/kubernetes/charts/tree/master/stable/postgresql) chart is deployed and used as database.
Please refer to this chart for additional PostgreSQL configuration options.

#### Using an External Database

The Keycloak Docker image supports PostgreSQL, MySQL, MariaDB, and H2.
The password for the database user is read from a Kubernetes secret.
It is possible to specify an existing secret that is not managed with this chart.
The key in the secret the password is read from may be specified as well (defaults to `password`).

```yaml
keycloak:
  persistence:

    # Disable deployment of the PostgreSQL chart
    deployPostgres: false

    # The database vendor. Can be either "postgres", "mysql", "mariadb", or "h2"
    dbVendor: postgres

    ## The following values only apply if "deployPostgres" is set to "false"

    # Optionally specify an existing secret
    existingSecret: "my-database-password-secret"
    existingSecretPasswordKey: "password-key-in-my-database-secret"
    existingSecretUsernameKey: "username-key-in-my-database-secret"

    dbName: keycloak
    dbHost: mykeycloak
    dbPort: 5432 # 5432 is PostgreSQL's default port. For MySQL it would be 3306
    dbUser: keycloak

    # Only used if no existing secret is specified. In this case a new secret is created
    dbPassword: keycloak
```

See also:
* https://github.com/jboss-dockerfiles/keycloak/blob/master/server/tools/cli/databases/postgres/change-database.cli
* https://github.com/jboss-dockerfiles/keycloak/blob/master/server/tools/cli/databases/mysql/change-database.cli

### Configuring Additional Environment Variables

```yaml
keycloak:
  extraEnv: |
    - name: KEYCLOAK_LOGLEVEL
      value: DEBUG
    - name: WILDFLY_LOGLEVEL
      value: DEBUG
    - name: CACHE_OWNERS
      value: "3"
    - name: DB_QUERY_TIMEOUT
      value: "60"
    - name: DB_VALIDATE_ON_MATCH
      value: true
    - name: DB_USE_CAST_FAIL
      value: false
```

### Providing a Custom Theme

One option is certainly to provide a custom Keycloak image that includes the theme.
However, if you prefer to stick with the official Keycloak image, you can use an init container as theme provider.

Create your own theme and package it up into a Docker image.

```docker
FROM busybox
COPY mytheme /mytheme
```

In combination with an `emptyDir` that is shared with the Keycloak container, configure an init container that runs your theme image and copies the theme over to the right place where Keycloak will pick it up automatically.

```yaml
keycloak:
  extraInitContainers: |
    - name: theme-provider
      image: myuser/mytheme:1
      imagePullPolicy: IfNotPresent
      command:
        - sh
      args:
        - -c
        - |
          echo "Copying theme..."
          cp -R /mytheme/* /theme
      volumeMounts:
        - name: theme
          mountPath: /theme

  extraVolumeMounts: |
    - name: theme
      mountPath: /opt/jboss/keycloak/themes/mytheme

  extraVolumes: |
    - name: theme
      emptyDir: {}
```

### Setting a Custom Realm

A realm can be added by creating a secret or configmap for the realm json file and then supplying this into the chart.
It could be mounted using `extraVolumeMounts` and then specified in `extraArgs` using `-Dkeycloak.import`.
First we could create a Secret from a json file using `kubectl create secret generic realm-secret --from-file=realm.json` which we need to reference in `values.yaml`:

```yaml
keycloak:
  extraVolumes: |
    - name: realm-secret
      secret:
        secretName: realm-secret

  extraVolumeMounts: |
    - name: realm-secret
      mountPath: "/realm/"
      readOnly: true

  extraArgs: -Dkeycloak.import=/realm/realm.json
```

Alternatively, the file could be added to a custom image (set in `keycloak.image`) and then referenced by `-Dkeycloak.import`.

After startup the web admin console for the realm should be available on the path /auth/admin/\<realm name>/console/.

### Using Google Cloud SQL Proxy

Depending on your environment you may need a local proxy to connect to the database.
This is, e. g., the case for Google Kubernetes Engine when using Google Cloud SQL.
Create the secret for the credentials as documented [here](https://cloud.google.com/sql/docs/postgres/connect-kubernetes-engine) and configure the proxy as a sidecar.

Because `keycloak.extraContainers` is a string that is passed through the `tpl` function, it is possible to create custom values and use them in the string.

```yaml

# Custom values for Google Cloud SQL
cloudsql:
  project: my-project
  region: europe-west1
  instance: my-instance

keycloak:
  extraContainers: |
    - name: cloudsql-proxy
      image: gcr.io/cloudsql-docker/gce-proxy:1.11
      command:
        - /cloud_sql_proxy
      args:
        - -instances={{ .Values.cloudsql.project }}:{{ .Values.cloudsql.region }}:{{ .Values.cloudsql.instance }}=tcp:5432
        - -credential_file=/secrets/cloudsql/credentials.json
      volumeMounts:
        - name: cloudsql-creds
          mountPath: /secrets/cloudsql
          readOnly: true

  extraVolumes: |
    - name: cloudsql-creds
      secret:
        secretName: cloudsql-instance-credentials

  persistence:
    deployPostgres: false
    dbVendor: postgres
    dbName: postgres
    dbHost: 127.0.0.1
    dbPort: 5432
    dbUser: myuser
    dbPassword: mypassword
```

### WildFly Configuration

WildFly can be configured via its [command line interface (CLI)](https://docs.jboss.org/author/display/WFLY/Command+Line+Interface).
This chart uses the official Keycloak Docker image and customizes the installation running CLI scripts at server startup.

#### Customizing CLI Scripts

In order to make further customization easier, the CLI commands are separated by their concerns into smaller scripts.
Everything is in `values.yaml` and can be overridden.
Additional CLI commands may be added via `keycloak.cli.custom`, which is empty by default.

#### Disabling CLI Changes

The CLI changes the chart makes may not be desirable in all cases, especially when a custom Keycloak image is used that already incorporates a complete configuration that doesn't need any adjustments.
In this case, the CLI scripts the chart runs by default can either be disabled en bloc or on and individual basis.

##### Disabling all CLI Changes en Bloc

```yaml
keycloak:
  cli:
    enabled: false
```

##### Disabling an Individual Script

```yaml
keycloak:
  cli:
    logging: ""
```

### High Availability and Clustering

For high availability, Keycloak should be run with multiple replicas (`keycloak.replicas > 1`).
WildFly uses Infinispan for caching.
These caches can be replicated across all instances forming a cluster.
If `keycloak.replicas > 1`, JGroups' DNS_PING is configured for cluster discovery and Keycloak is started with `--server-config standalone-ha.xml`.

### Prometheus Operator Support

It is possible to monitor Keycloak with Prometheus through the use of plugins such as [keycloak-metrics-spi](https://github.com/aerogear/keycloak-metrics-spi). The plugin can be added with configuration like this:
```
  extraInitContainers: |
    - name: extensions
      image: busybox
      imagePullPolicy: IfNotPresent
      command:
        - sh
      args:
        - -c
        - |
          echo "Copying extensions..."
          wget -O /deployments/keycloak-metrics-spi.jar https://github.com/aerogear/keycloak-metrics-spi/releases/download/1.0.1/keycloak-metrics-spi-1.0.1.jar
      volumeMounts:
        - name: deployments
          mountPath: /deployments

  extraVolumeMounts: |
    - name: deployments
      mountPath: /opt/jboss/keycloak/standalone/deployments

  extraVolumes: |
    - name: deployments
      emptyDir: {}
```

You can then either configure Prometheus to scrape the `/auth/realms/master/metrics` path on the normal HTTP port of JBoss, or if you use the [Prometheus Operator](https://github.com/helm/charts/tree/master/stable/prometheus-operator) you can enable `prometheus.operator.enabled` in `values.yaml` and use the example configuration.
If you are using Prometheus Operator for configuring Prometheus Rules, the chart also supports this; see `prometheus.operator.prometheusRules` in `values.yaml` for more details.

## Why StatefulSet?

The chart sets node identifiers to the system property `jboss.node.name` which is in fact the pod name.
Node identifiers must not be longer than 23 characters.
This can be problematic because pod names are quite long.
We would have to truncate the chart's fullname to six characters because pods get a 17-character suffix (e. g. `-697f8b7655-mf5ht`).
Using a StatefulSet allows us to truncate to 20 characters leaving room for up to 99 replicas, which is much better.
Additionally, we get stable values for `jboss.node.name` which can be advantageous for cluster discovery.
The headless service that governs the StatefulSet is used for DNS discovery.

## Upgrading

### From chart versions < 8.0.0

* Keycloak is updated to 10.0.0
* PostgreSQL chart dependency is updated to 8.9.5

The upgrade should be seemless.
No special care has to be taken.

### From chart versions < 7.0.0

Version 7.0.0 update breaks backwards-compatibility with the existing `keycloak.persistence.existingSecret` scheme.

#### Changes in Configuring Database Credentials from an Existing Secret

Both `DB_USER` and `DB_PASS` are always read from a Kubernetes Secret.
This is a requirement if you are provisioning database credentials dynamically - either via an Operator or some secret-management engine.

The variable referencing the password key name has been renamed from `keycloak.persistence.existingSecretKey` to `keycloak.persistence.existingSecretPasswordKey`

A new, optional variable for referencing the username key name for populating the `DB_USER` env has been added:
`keycloak.persistence.existingSecretUsernameKey`.

If `keycloak.persistence.existingSecret` is left unset, a new Secret will be provisioned populated with the `dbUser` and `dbPassword` Helm variables.

###### Example configuration:
```yaml
keycloak:
  persistence:
    existingSecret: keycloak-provisioned-db-credentials
    existingSecretPasswordKey: PGPASSWORD
    existingSecretUsernameKey: PGUSER
    ...
```
### From chart versions < 6.0.0

#### Changes in Probe Configuration

Now both readiness and liveness probes are configured as strings that are then passed through the `tpl` function.
This allows for greater customizability of the readiness and liveness probes.

The defaults are unchanged, but since 6.0.0 configured as follows:

```yaml
  livenessProbe: |
    httpGet:
      path: {{ if ne .Values.keycloak.basepath "" }}/{{ .Values.keycloak.basepath }}{{ end }}/
      port: http
    initialDelaySeconds: 300
    timeoutSeconds: 5
  readinessProbe: |
    httpGet:
      path: {{ if ne .Values.keycloak.basepath "" }}/{{ .Values.keycloak.basepath }}{{ end }}/realms/master
      port: http
    initialDelaySeconds: 30
    timeoutSeconds: 1
```

#### Changes in Existing Secret Configuration

This can be useful if you create a secret in a parent chart and want to reference that secret.
Applies to `keycloak.existingSecret` and `keycloak.persistence.existingSecret`.

_`values.yaml` of parent chart:_
```yaml
keycloak:
  keycloak:
    existingSecret: '{{ .Release.Name }}-keycloak-secret'
```

#### HTTPS Port Added

The HTTPS port was added to the pod and to the services.
As a result, service ports are now configured differently.


### From chart versions < 5.0.0

Version 5.0.0 is a major update.

* The chart now follows the new Kubernetes label recommendations:
https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/
* Several changes to the StatefulSet render an out-of-the-box upgrade impossible because StatefulSets only allow updates to a limited set of fields
* The chart uses the new support for running scripts at startup that has been added to Keycloak's Docker image.
If you use this feature, you will have to adjust your configuration

However, with the following manual steps an automatic upgrade is still possible:

1. Adjust chart configuration as necessary (e. g. startup scripts)
1. Perform a non-cascading deletion of the StatefulSet which keeps the pods running
1. Add the new labels to the pods
1. Run `helm upgrade`

Use a script like the following to add labels and to delete the StatefulSet:

```console
#!/bin/sh

release=<release>
namespace=<release_namespace>

kubectl delete statefulset -n "$namespace" -l app=keycloak -l release="$release" --cascade=false

kubectl label pod -n "$namespace" -l app=keycloak -l release="$release" app.kubernetes.io/name=keycloak
kubectl label pod -n "$namespace" -l app=keycloak -l release="$release" app.kubernetes.io/instance="$release"
```

**NOTE:** Version 5.0.0 also updates the Postgresql dependency which has received a major upgrade as well.
In case you use this dependency, the database must be upgraded first.
Please refer to the Postgresql chart's upgrading section in its README for instructions.

