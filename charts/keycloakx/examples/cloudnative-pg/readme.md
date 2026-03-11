# Keycloak.X with PostgreSQL

This example shows how to configure Keycloak.X to use a PostgreSQL database.

# Setup

## Add repository
```
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo add codecentric https://codecentric.github.io/helm-charts
```

## Update helm repos
```
helm repo update
```

## Deploy a PostgreSQL database
```
kubectl apply -f keycloak-cluster.yaml
kubectl wait -for=condition=Ready cluster/keycloak-database --timeout=300s
```

# Deploy Keycloak
```
helm install keycloak codecentric/keycloakx --values ./keycloak-server-values.yaml
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
kubectl delete -f keycloak-cluster.yaml
```
