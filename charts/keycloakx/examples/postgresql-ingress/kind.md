Cluster setup with kind
----

This example creates a local Kubernetes cluster running on the local docker host with [Kind](https://kind.sigs.k8s.io/).

The following steps are described in more detail in the [Kind documentation](https://kind.sigs.k8s.io/docs/user/ingress/).

# Create kind cluster

```
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
```

# Deploy Nginx Controller
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

Once the Nginx ingress controller is running we can go on and deploy the Keycloak helm chart.