# Mailhog

[Mailhog](http://iankent.uk/project/mailhog/) is an e-mail testing tool for developers.

## TL;DR;

```bash
$ helm repo add codecentric https://codecentric.github.io/helm-charts
$ helm install mailhog codecentric/mailhog
```

## Introduction

This chart creates a [Mailhog](http://iankent.uk/project/mailhog/) deployment on a [Kubernetes](http://kubernetes.io)
cluster using the [Helm](https://helm.sh) package manager.

## Installing the Chart

To install the chart with the release name `mailhog`:

```bash
$ helm install mailhog codecentric/mailhog
```

The command deploys Mailhog on the Kubernetes cluster in the default configuration. The [configuration](#configuration)
section lists the parameters that can be configured during installation.

## Uninstalling the Chart

To uninstall/delete the `mailhog` deployment:

```bash
$ helm uninstall mailhog
```
The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following table lists the configurable parameters of the Mailhog chart and their default values.

Parameter | Description | Default
--- | --- | ---
`extraContainers` | Additional containers to be added to the application pod | `[]`
`image.repository` | Docker image repository | `mailhog/mailhog`
`image.tag` | Docker image tag whose default is the chart version | `""`
`image.pullPolicy` | Docker image pull policy | `IfNotPresent`
`imagePullSecrets` | Docker image pull secrets | `[]`
`auth.enabled` | Specifies whether basic authentication is enabled, see [Auth.md](https://github.com/mailhog/MailHog/blob/master/docs/Auth.md) | `false`
`auth.existingSecret` | If auth is enabled, uses an existing secret with this name; otherwise a secret is created | `""`
`auth.fileName` | The name of the auth file | `auth.txt`
`auth.fileContents` | The contents of the auth file | `""`
`affinity` | Node affinity for pod assignment | `{}`
`containerPort.http.name` | Configure the Http name of the Mailhog container | `http`
`containerPort.http.port` | Configure the Http port of the Mailhog container | `8025`
`containerPort.smtp.name` | Configure the Smtp name of the Mailhog container | `tcp-smtp`
`containerPort.smtp.port` | Configure the Smtp port of the Mailhog container | `1025`
`nodeSelector` | Node labels for pod assignment | `{}`
`podReplicas` | The number of pod replicas | `1`
`podAnnotations` | Extra annotations to add to pod | `{}`
`podLabels` | Extra labels to add to pod | `{}`
`resources` | Pod resource requests and limits | `{}`
`tolerations` | Node taints to tolerate | `[]`
`priorityClassName` | Name of the existing priority class to be used by Mailhog pod, priority class needs to be created beforehand | `""`
`livenessProbe` | The Liveness Probe to add to pod | `{ "initialDelaySeconds": 10, "tcpPort": { "port": "1025" }, "timeoutSeconds": 1 }`
`readinessProbe` | The Readiness Probe to add to pod | `{"tcpPort": { "port": "1025" }`
`serviceAccount.create` | Specifies whether a ServiceAccount should be created | `true` |
`serviceAccount.name` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template | `""` |
`serviceAccount.imagePullSecrets` | Image pull secrets that are attached to the ServiceAccount | `[]` |
`automountServiceAccountToken` | Indicates whether the service account token should be automatically mounted | `false` |
`service.annotations` | Annotations for the service | `{}`
`service.clusterIP` | Internal cluster service IP | `""`
`service.externalIPs` | Service external IP addresses | `[]`
`service.extraPorts` | Additional ports to the service | `[]`
`service.loadBalancerIP` | IP address to assign to load balancer (if supported) | `""`
`service.loadBalancerSourceRanges` | List of IP CIDRs allowed access to load balancer (if supported) | `[]`
`service.type` | Type of service to create | `ClusterIP`
`service.namedTargetPort` | Use named target port for service | `true`
`service.port.http` | HTTP port of service | `""`
`service.port.smtp` | SMTP port of service | `""`
`service.nodePort.http` | If `service.type` is `NodePort` and this is non-empty, sets the http node port of the service | `""`
`service.nodePort.smtp` | If `service.type` is `NodePort` and this is non-empty, sets the smtp node port of the service | `""`
`securityContext` | Pod security context | `{ runAsUser: 1000, fsGroup: 1000, runAsNonRoot: true }`
`ingress.enabled` | If `true`, an ingress is created | `false`
`ingress.ingressClassName` | If set the created Ingress resource will have this class name. kubernetes.io/ingress.class is [deprecated](https://kubernetes.io/docs/concepts/services-networking/ingress/#deprecated-annotation) | `nil`
`ingress.annotations` | Annotations for the ingress | `{}`
`ingress.labels` | Labels for the ingress | `{}`
`ingress.hosts` | A list of ingress hosts | `{ host: mailhog.example.com, paths: [{ path: "/", pathType: Prefix }] }`
`ingress.tls` | A list of [IngressTLS](https://v1-8.docs.kubernetes.io/docs/api-reference/v1.8/#ingresstls-v1beta1-extensions) items | `[]`
`extraEnv` | Additional environment variables, see [CONFIG.md](https://github.com/mailhog/MailHog/blob/master/docs/CONFIG.md) | `{}`

## Upgrading

### From chart < 5.0.0

 Ingress path definitions are extended to describe path and pathType. Previously only the path was configured. Please adapt your configuration as shown below:

 Old:
 ```yaml
 ingress:
   # ...
   hosts:
     - host: mailhog.example.com
       # Paths for the host
       paths:
         - /
 ```
 New:
 ```yaml
 ingress:
   # ...
   hosts:
     - host: mailhog.example.com
       # Paths for the host
       paths:
         - path: /
           pathType: Prefix
 ```

 This allows to configure specific `pathType` configurations, e.g. `pathType: ImplementationSpecific` for [GKE Ingress on Google Cloud Platform](https://cloud.google.com/kubernetes-engine/docs/concepts/ingress#default_backend).
