# adplatform Kubernetes manifests

This folder contains example Kubernetes manifests for the adplatform stack used for development and testing. It is intentionally conservative and contains placeholders which should be replaced/pinned for production use.

Files included:

- `namespace.yaml` - Namespace `adplatform`.
- `scylla-statefulset.yaml` - ScyllaDB headless Service, ClusterIP Service, and StatefulSet with PVC template.
- `dragonfly-deployment.yaml` - DragonflyDB (Redis-compatible) Deployment and Service.
- `redpanda-statefulset.yaml` - Redpanda headless Service, ClusterIP Service, and StatefulSet with PVC template.
- `varnish-deployment.yaml` - Varnish ConfigMap, Deployment and Service (points to `user-management:8080`).
- `envoy-config.yaml` + `envoy-deployment.yaml` - Envoy ConfigMap and Deployment (LoadBalancer) routing to `user-management`.
- `katran-daemonset.yaml` - Template DaemonSet for Katran (placeholder image). Requires privileged host access and kernel modules; see notes below.
- `user-management-deployment.yaml` - Deployment and Service for the Rust Actix Web `user-management` microservice (image placeholder `orazesen/user-management:latest`).

Quick apply (development cluster):

```sh
# create namespace
kubectl apply -f k8s/namespace.yaml

# create all manifests (in namespace)
kubectl apply -f k8s/
```

Important notes and placeholders:

- Images use `latest` tags or placeholders in several manifests. Pin image tags before deploying to staging/production.
- `katran-daemonset.yaml` is a template. Katran requires kernel/eBPF support and often custom node prep. You must provide a validated Katran image and ensure nodes are configured for it. The DaemonSet runs privileged and uses host networking.
- StorageClass name `standard` is used for PVC templates — adjust to your cluster's storage class.
- Envoy is configured with a basic listener that forwards all HTTP to `user-management:8080`. Update the Envoy config for TLS, health checks, metrics, and advanced routing as needed.
- Varnish default VCL points to `user-management`; adapt backend configuration for other services or caching policies.
- Redpanda may require additional node tuning (sysctl, ulimits) for production; this YAML is a minimal example.

Next steps (recommended):

1. Replace placeholder images with pinned, trusted images.
2. Add readiness/liveness probes and resource limits tuned to your workloads.
3. Add RBAC, network policies, and TLS for cross-service traffic.
4. For stateful systems (Scylla, Redpanda), test rolling upgrades and backup/restore procedures.
