# Keycloak.X with PostgreSQL and NGinx Ingress Controller

This example shows how to configure Keycloak.X to use a PostgreSQL database.

# Setup

## Setup Keycloak cluster
If you already have a running Keycloak cluster with an Ingress controller configured you can skip this section.

If you want to try this example with a locally running Keycloak cluster, checkout the [Kind Kubernetes cluster example](./kind.md).

## Add repository
```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add codecentric https://codecentric.github.io/helm-charts
```

## Update helm repos
```
helm repo update
```

## Deploy Ingress Controller

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

## Deploy a PostgreSQL database
```
helm install keycloak-db bitnami/postgresql --values ./keycloak-db-values.yaml
```

# Deploy Keycloak
```
helm install keycloak codecentric/keycloakx --values ./keycloak-server-values.yaml
```

# Access Keycloak

Once Keycloak is running, we should be able to access Keycloak with the configured domain, 
e.g.: https://id.acme.test/auth.

See the [Keycloak with Postgres Example](../postgresql/readme.md) for accessing the Keycloak with a port forward.

You can then access the Keycloak Admin-Console via `https://id.acme.test/auth` with
the username: `admin` and password: `secret`.

# Remove Keycloak

```
helm uninstall keycloak
helm uninstall keycloak-db
```
