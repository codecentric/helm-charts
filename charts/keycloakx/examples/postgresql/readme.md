# Example for using Keycloak.X with PostgreSQL

## Deploy a PostgreSQL database
```
helm install keycloak-db bitnami/postgresql --values ./charts/keycloakx/examples/keycloak-db-values.yaml
```

# Deploy Keycloak
```
helm install keycloak ./charts/keycloakx --values ./charts/keycloakx/examples/keycloak-server-values.yaml
```

# Access Keycloak
Once Keycloak is running, forward the HTTP service port to 8080.

```
kubectl port-forward service/keycloak-keycloakx-http 8080:80
```

You can then access the Keycloak Admin-Console via `http://localhost:8080/auth` with
username: `admin` and password: `secret`.
