# Keycloak.X with KUBE_PING

This example shows how to use KUBE_PING JGroup cluster discovery with Keycloak.X.

Since Keycloak.X (17.0.x, 18.0.x) does not support jgroups KUBE_PING out of the box,
we need to download the library and copy it into a custom docker image.

Note that we use some customizations in the `keycloak-server-values.yaml` file:
- Set environment variable `KC_CACHE_CONFIG_FILE=cache-ispn-kubeping.xml` to our custom cache config file
- Disable automatic cache configuration via `cache.stack=custom`
- Configure `kubeping_namespace` and `kubeping_label` system properties via `JAVA_OPTS_APPEND`
- Configure serviceAccount.create=true and serviceAccount.allowReadPods=true to allow kube_ping to enlist keycloak pods

# Setup

## Add repository
```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add codecentric https://codecentric.github.io/helm-charts
```

## Update helm repos
```
helm repo update
```

## Build custom Docker Image

This custom image automatically downloads the jgroups-kubernetes library.
```
docker build -t thomasdarimont/keycloakx-kubeping .
```

We need to make the custom docker image available in the Kubernetes cluster. This is up to your k8s environment.
With [kind](https://kind.sigs.k8s.io/docs/user/quick-start/) you can use `kind load docker-image thomasdarimont/keycloakx-kubeping:latest`.

## Deploy a PostgreSQL database
```
helm install keycloak-db bitnami/postgresql --values ./keycloak-db-values.yaml
```

# Deploy Keycloak

```
helm install keycloak codecentric/keycloakx --values ./keycloak-server-values.yaml
```

If everything worked you should now see log entries like this:
```
...
keycloak 2022-04-09 15:14:55,997 INFO  [org.jgroups.protocols.kubernetes.KUBE_PING] (keycloak-cache-init) namespace default set; clustering enabled
...
```

On a new Keycloak pod you should see the following log entries:
```
...
15:16:20,184 INFO  [org.jgroups.protocols.kubernetes.KUBE_PING] (keycloak-cache-init) namespace default set; clustering enabled
15:16:20,395 INFO  [org.infinispan.CLUSTER] (keycloak-cache-init) ISPN000094: Received new cluster view for channel ISPN: [keycloak-keycloakx-0-34953|1] (2) [keycloak-keycloakx-0-34953, keycloak-keycloakx-1-34016]
15:16:20,399 INFO  [org.infinispan.CLUSTER] (keycloak-cache-init) ISPN000079: Channel `ISPN` local address is `keycloak-keycloakx-1-34016`, physical addresses are `[10.244.0.22:7800]`
...
```

# Access Keycloak
Once Keycloak is running, forward the HTTP service port to 8080.

```
kubectl port-forward service/keycloak-keycloakx-http 8080:80
```

You can then access the Keycloak Admin-Console via `http://localhost:8080/auth` with
username: `admin` and password: `secret`.

# Remove Keycloak

```
helm uninstall keycloak
helm uninstall keycloak-db
```
