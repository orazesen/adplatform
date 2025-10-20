## DAY 1 — Final‑Stage Quickstart (No Migrations)

Goal: start development and deploy the final production-grade stack right away (Seastar hot paths + Glommio control plane + ScyllaDB, DragonflyDB, Redpanda, ClickHouse, Envoy, Katran). This guide is pragmatic: minimal steps to reach the production topology described in the docs.

Audience: SRE / Senior backend engineer who can run commands on Linux servers and build C++/Rust code.

Assumptions & short contract

- 3 Linux servers (bare-metal or VMs) for a minimal production cluster: 3 control/infra nodes. Prefer 64 cores, 256GB RAM, NVMe.
- Goal outputs: running ScyllaDB cluster, Redpanda, DragonflyDB, ClickHouse, MinIO, Envoy L7 gateway, Katran L4 on edge nodes, Seastar services deployed and Glommio services deployed.
- Success criteria: each service's health endpoint OK; sample ad-serving endpoint responds; basic load validation using wrk2.

High-level steps (one-liner view)

1. OS & kernel tuning (hugepages, IRQ, sysctl)
2. Install packages: build toolchain, Docker, k3s, helm
3. Provision K3s cluster (3 nodes) with Cilium + hostNetwork enabled for hot-path pods
4. Deploy data plane: ScyllaDB, Redpanda, DragonflyDB, ClickHouse, MinIO via Helm
5. Deploy Envoy as L7 gateway and Katran on edge hosts (as DaemonSet or native) for L4
6. Build & deploy Seastar services (static binaries, hostNetwork, CPU pinning)
7. Build & deploy Glommio services (Cargo release, k8s deployments)
8. Validate (health checks, load tests, metrics)

Detailed steps

1. Prepare Linux hosts (repeat on each node)

- Pick Ubuntu 22.04 LTS (recommended) or a kernel >= 5.15 with io_uring and eBPF support.
- Basic packages & user

```bash
# create a user
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG sudo deploy

# install tooling
sudo apt update && sudo apt install -y build-essential cmake ninja-build git curl \
  libnuma-dev libhwloc-dev libssl-dev libboost-all-dev pkg-config docker.io \
  linux-headers-$(uname -r)

# add docker permissions for deploy user
sudo usermod -aG docker deploy
```

2. Kernel tuning (essential for Seastar/Scylla/Redpanda)

Add these to `/etc/sysctl.d/99-adplatform.conf` and apply with `sudo sysctl --system`:

```
vm.swappiness = 1
vm.max_map_count = 2621440
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 250000
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
```

Enable hugepages and set CPU governor to performance (example):

```bash
sudo sysctl -w vm.nr_hugepages=1024
sudo apt install -y cpufrequtils
sudo cpufreq-set -r -g performance
```

3. Install k3s + Cilium (lightweight Kubernetes for orchestration)

We use k3s for quick infra orchestration and Helm for charts. Hot-path Seastar containers will run with hostNetwork and CPU pinning to avoid CNI overhead.

On first node (control):

```bash
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
sudo mkdir -p /etc/rancher/k3s
```

Then on worker nodes, use the token from `/var/lib/rancher/k3s/server/node-token` to join.

Install Helm and Cilium via helm:

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium --version 1.14.0 --namespace kube-system --create-namespace \
  --set global.etcd.enabled=false
```

4. Deploy core data plane via Helm

Add recommended repos and install minimal production charts (values tuned for small clusters):

```bash
helm repo add scylla https://scylladb.github.io/charts
helm repo add redpanda https://charts.redpanda.com
helm repo add clickhouse https://clickhouse.github.io/helm-charts/
helm repo add minio https://charts.min.io/
helm repo update

# Scylla (3-node)
helm install scylla scylla/scylla --namespace scylla --create-namespace -f - <<'YAML'
replicaCount: 3
resources:
  requests:
    memory: "32Gi"
    cpu: "8"
YAML

# Redpanda (3-node, k8s)
helm install redpanda redpanda/redpanda --namespace streaming --create-namespace -f - <<'YAML'
replicas: 3
resources:
  requests:
    memory: "16Gi"
    cpu: "4"
YAML

# ClickHouse (single replica for day-1 testing)
helm install clickhouse clickhouse/clickhouse --namespace analytics --create-namespace

# MinIO (3-node distributed for objects)
helm install minio minio/minio --namespace storage --create-namespace -f - <<'YAML'
accessKey: minio
secretKey: minio123
replicas: 3
YAML

# DragonflyDB: no official helm; run as DaemonSet or StatefulSet with container image
kubectl apply -f deploy/dragonflydb-statefulset.yaml
```

Note: charts above require values tuning for production. The manifest `deploy/dragonflydb-statefulset.yaml` is a small wrapper statefulset (you'll create or vendor a DragonflyDB image). For fastest production, run Scylla/Redpanda on bare-metal nodes (no virtualization) and use hostNetwork.

5. Edge: Katran & Envoy

Katran (L4) is kernel/eBPF based and typically runs on edge Linux hosts (not inside ordinary k8s pods). For Day‑1 test you can skip Katran and rely on cloud/host L4. If you want Katran immediately:

- Build and install Katran per project docs on each edge node (requires kernel with eBPF): https://github.com/facebookincubator/katran

Envoy (L7) — deploy via DaemonSet or Deployment; use hostNetwork for minimal overhead. Example minimal envoy deployment (hostNetwork + CPU limits):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: envoy
  namespace: ingress
spec:
  replicas: 3
  template:
    spec:
      hostNetwork: true
      containers:
        - name: envoy
          image: envoyproxy/envoy:v1.30.0
          resources:
            requests:
              cpu: "2000m"
              memory: "2Gi"
```

6. Build Seastar services (ad-serving, bidding) — recommended on a build machine and deploy artifacts to nodes

Prereqs (on build host):

```bash
# Seastar build dependencies (Ubuntu example)
sudo apt install -y cmake ninja-build pkg-config libnuma-dev libhwloc-dev ragel libssl-dev liblz4-dev

git clone https://github.com/scylladb/seastar.git
cd seastar
./configure.py --mode=release --c++-standard=20
ninja -C build/release

# Build your Seastar-based service (example: services/ad-server)
cd /workspace/adplatform/services/ad-server
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
ninja

# Produce a static binary (strip for size)
strip ad-server
scp ad-server deploy@node1:/opt/adplatform/bin/
```

Run Seastar binary on node with hostNetwork and CPU pinning. Use systemd unit that pins CPUs and sets hugepages and ulimit:

Example systemd unit (/etc/systemd/system/ad-server.service):

[Unit]
Description=Ad Server (Seastar)
After=network.target

[Service]
User=deploy
ExecStart=/opt/adplatform/bin/ad-server --cpuset 0-47 --memory 64G
LimitNOFILE=1048576
Restart=on-failure
CPUAffinity=0-47

[Install]
WantedBy=multi-user.target

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now ad-server
```

7. Build & deploy Glommio services (control plane)

On build host:

```bash
cd services/campaign-mgmt
cargo build --release
scp target/release/campaign-mgmt deploy@node2:/opt/adplatform/bin/

# Run inside k3s as Deployment (containerize or use ExecStart on systemd)
kubectl create deployment campaign-mgmt --image=ghcr.io/yourorg/campaign-mgmt:latest -n control
kubectl set resources deployment/campaign-mgmt -n control --requests=cpu=500m,memory=1Gi
```

Prefer to containerize Glommio services with a minimal image (scratch or distroless) and deploy via k8s.

8. Observability & basic checks

Deploy Prometheus / Grafana / Loki / Jaeger via Helm (observability namespace). Example:

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install observability grafana/grafana --namespace observability --create-namespace
```

Health checks (examples):

```bash
kubectl get pods -A
curl -f http://<ad-server-host>:8080/health || echo 'ad-server not healthy'
curl -f http://<scylla-service>:10000/health || echo 'scylla not healthy'
```

9. Quick validation (load test)

From a client machine (not on same hosts):

```bash
# basic latency/load smoke test
wrk2 -t8 -c200 -d30s -R10000 http://<envoy-or-adserver-ip>:8080/ad

# sample success criterion: 10k RPS on day-1 cluster or your target minimum
```

10. Production checklist (short)

- Monitoring: Prometheus metrics + Grafana dashboards for Seastar, Scylla, Redpanda, DragonflyDB
- Backups: enable Scylla snapshots, ClickHouse backups to MinIO
- Security: enable mTLS on Envoy, WAF rules on edge, restrict management ports
- Performance builds: enable PGO and LTO for Seastar binaries
- Kernel tuning automated (Ansible/Chef) — keep configs in repo
- Capacity planning: disk, NICs (100GbE recommended), NUMA-aware layout

Notes and trade-offs

- Seastar performs best on bare-metal with pinned CPUs and host networking. Running Seastar inside k8s is acceptable if hostNetwork is used and CPU pinning applied — but prefer dedicated application nodes.
- Katran must be installed on physical edge hosts to use XDP/eBPF L4; it is not a simple k8s deployment.
- This quickstart favors production-grade components; tune Helm charts' values for real capacity before traffic ramp.

Where to find more details

- FASTEST_STACK.md — component rationale and benchmarks
- ARCHITECTURE.md — topology and design details
- TECH_STACK.md — exact build flags, dependencies, and examples

Completion summary

- You now have a single-page Day‑1 plan to provision and run the final-stage stack: OS/kernel tuning, k3s + Cilium, Helm deploys for data plane, systemd or k8s deployment for Seastar binaries, and containerized Glommio control plane. Use the production checklist above to convert this into repeatable Ansible/Terraform/Helm charts.

If you want, I can:

- generate the minimal `dragonflydb` StatefulSet manifest used above
- produce example systemd unit files and a small `Makefile`/`scripts/deploy.sh` to automate builds and deploys
- create HelmValue templates for Seastar services with CPU pinning and hostNetwork

**_ End of DAY 1 quickstart _**
