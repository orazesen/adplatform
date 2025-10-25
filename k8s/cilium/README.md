# Cilium Setup for adplatform

This directory contains Cilium installation and network policy configuration for the adplatform Kubernetes cluster.

## Components

- **install-cilium.sh**: Install script using Helm with your local `cilium/cilium:v1.18.3` image
- **networkpolicies/**: CiliumNetworkPolicy manifests for secure traffic flow

## Prerequisites

1. **Helm 3** installed on your machine
2. **kubectl** configured for docker-desktop context
3. **Local Cilium image** (confirmed: `cilium/cilium:v1.18.3`)

## Installation Steps

### 1. Install Cilium

Make the install script executable and run it:

```bash
chmod +x k8s/cilium/install-cilium.sh
./k8s/cilium/install-cilium.sh
```

This will:

- Add the Cilium Helm repo
- Install Cilium v1.18.3 using your local Docker image
- Enable Hubble for observability
- Set `kubeProxyReplacement=partial` (safe default)

### 2. Verify Installation

Check Cilium pods are running:

```bash
kubectl -n kube-system get pods -l k8s-app=cilium
kubectl -n kube-system get pods -l k8s-app=cilium-operator
```

All pods should be in `Running` state.

### 3. Apply Network Policies

Apply the conservative network policies to secure your adplatform namespace:

```bash
kubectl apply -f k8s/cilium/networkpolicies/
```

This applies:

- **allow-dns.yaml**: Allow all pods to access DNS
- **allow-envoy-ingress.yaml**: Allow external traffic to Envoy
- **allow-envoy-to-varnish.yaml**: Envoy → Varnish (port 80)
- **allow-envoy-to-user-management.yaml**: Envoy → user-management (port 8080) — for non-cacheable paths
- **allow-varnish-to-user-management.yaml**: Varnish → user-management (port 8080)
- **allow-egress.yaml**: Allow necessary egress from Envoy and Varnish

### 4. Verify Network Policies

List applied policies:

```bash
kubectl -n adplatform get ciliumnetworkpolicies
```

## Observability with Hubble

### Port-forward Hubble UI

```bash
kubectl -n kube-system port-forward svc/hubble-ui 12000:80
```

Then open http://localhost:12000 in your browser to see:

- Service map and flow visualization
- Real-time traffic between Envoy → Varnish → user-management
- Allowed/denied flows

### Command-line Flow Observation

If you have the Hubble CLI installed:

```bash
hubble observe --namespace adplatform --follow
```

## Testing the Setup

1. **Test Envoy port-forward** (should still work):

   ```bash
   kubectl -n adplatform port-forward svc/envoy 8080:80
   curl -v http://localhost:8080/
   ```

2. **Verify traffic flows** in Hubble UI while testing

3. **Check for policy violations**:
   ```bash
   hubble observe --namespace adplatform --verdict DROPPED
   ```

## Network Policy Architecture

```
[External/Browser]
        ↓ (allowed)
    [Envoy:80]
        ↓ (cacheable) ──────────┐ (non-cacheable/API)
    [Varnish:80]                ↓
        ↓                       ↓
        └──────────→ [user-management:8080]
```

- DNS is allowed for all pods (coredns resolution)
- Envoy accepts external traffic
- Envoy can reach Varnish (for cacheable content) AND user-management (for APIs, auth, dynamic content)
- Varnish can only reach user-management
- user-management accepts from both Envoy and Varnish

## Rollback / Uninstall

To remove Cilium (will restore previous CNI):

```bash
helm uninstall cilium -n kube-system
```

To remove network policies only:

```bash
kubectl delete -f k8s/cilium/networkpolicies/
```

## Troubleshooting

### Pods stuck in Pending or CrashLoopBackOff

Check Cilium agent logs:

```bash
kubectl -n kube-system logs -l k8s-app=cilium --tail=50
```

### Network connectivity issues after install

1. Check Cilium status:

   ```bash
   kubectl -n kube-system exec -it ds/cilium -- cilium status
   ```

2. Temporarily remove network policies to test:

   ```bash
   kubectl delete cnp -n adplatform --all
   ```

3. Reapply them one by one to find the problematic policy

### Hubble not accessible

Check Hubble relay is running:

```bash
kubectl -n kube-system get pods -l k8s-app=hubble-relay
kubectl -n kube-system logs -l k8s-app=hubble-relay
```

## Benefits of Cilium in This Architecture

1. **eBPF-based networking**: High performance, low latency
2. **Identity-aware security**: Policies based on labels, not IPs
3. **L7 visibility**: See HTTP requests in Hubble (useful for debugging cache hits/misses)
4. **Service mesh features**: Optional transparent encryption, circuit breaking
5. **Observability**: Hubble provides real-time visibility into traffic flows

## Next Steps

- Monitor Hubble flows while testing Varnish caching
- Add more granular L7 policies if needed (e.g., HTTP method/path restrictions)
- Enable Cilium metrics and integrate with Prometheus/Grafana
- Consider enabling transparent encryption for intra-cluster traffic
