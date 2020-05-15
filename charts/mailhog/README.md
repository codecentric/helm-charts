# Mailhog

[Mailhog](http://iankent.uk/project/mailhog/) is an e-mail testing tool for developers.

## TL;DR;

```bash
$ helm install stable/mailhog
```

## Introduction

This chart creates a [Mailhog](http://iankent.uk/project/mailhog/) deployment on a [Kubernetes](http://kubernetes.io)
cluster using the [Helm](https://helm.sh) package manager.

## Prerequisites

- Kubernetes 1.9+ with Beta APIs enabled

## Installing the Chart

To install the chart with the release name `my-release`:

```bash
$ helm install --name my-release codecentric/mailhog
```

The command deploys Mailhog on the Kubernetes cluster in the default configuration. The [configuration](#configuration)
section lists the parameters that can be configured during installation.

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```bash
$ helm delete my-release
```
The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following table lists the configurable parameters of the Mailhog chart and their default values.

Parameter | Description | Default
--- | --- | ---
`image.repository` | Docker image repository | `mailhog/mailhog`
`image.tag` | Docker image tag | `v1.0.0`
`image.pullPolicy` | Docker image pull policy | `IfNotPresent`
`auth.enabled` | Specifies whether basic authentication is enabled, see [Auth.md](https://github.com/mailhog/MailHog/blob/master/docs/Auth.md) | `false`
`auth.existingSecret` | If auth is enabled, uses an existing secret with this name; otherwise a secret is created | `""`
`auth.fileName` | The name of the auth file | `auth.txt`
`auth.fileContents` | The contents of the auth file | `""`
`nodeSelector` | Node labels for pod assignment | `{}`
`podAnnotations` | Extra annotations to add to pod | `{}`
`podLabels` | Extra labels to add to pod | `{}`
`resources` | Pod resource requests and limits | `{}`
`tolerations` | Node taints to tolerate | `[]`
`service.annotations` | Annotations for the service | `{}`
`service.clusterIP` | Internal cluster service IP | `""`
`service.externalIPs` | Service external IP addresses | `[]`
`service.loadBalancerIP` | IP address to assign to load balancer (if supported) | `""`
`service.loadBalancerSourceRanges` | List of IP CIDRs allowed access to load balancer (if supported) | `[]`
`service.type` | Type of service to create | `ClusterIP`
`service.node.http` | HTTP port of service | `""`
`service.node.smtp` | SMTP port of service | `""`
`service.nodePort.http` | If `service.type` is `NodePort` and this is non-empty, sets the http node port of the service | `""`
`service.nodePort.smtp` | If `service.type` is `NodePort` and this is non-empty, sets the smtp node port of the service | `""`
`securityContext` | Pod security context | `{ runAsUser: 1000, fsGroup: 1000, runAsNonRoot: true }`
`ingress.enabled` | If `true`, an ingress is created | `false`
`ingress.annotations` | Annotations for the ingress | `{}`
`ingress.hosts` | A list of ingress hosts | `{ host: mailhog.example.com, paths: ["/"] }`
`ingress.tls` | A list of [IngressTLS](https://v1-8.docs.kubernetes.io/docs/api-reference/v1.8/#ingresstls-v1beta1-extensions) items | `[]`
`extraEnv` | Additional environment variables, see [CONFIG.md](https://github.com/mailhog/MailHog/blob/master/docs/CONFIG.md) | `{}`

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```bash
$ helm install --name my-release \
  --set env.MH_UI_WEB_PATH=mailhog \
    stable/mailhog
```

Alternatively, a YAML file that specifies the values for the parameters can be provided while installing the chart. For example,

```bash
$ helm install --name my-release -f values.yaml stable/mailhog
```
