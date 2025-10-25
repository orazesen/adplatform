# Development Environment Setup - Complete Guide

## Single-Node Kubernetes for 10 Developers

> **Author**: @orazesen  
> **Last Updated**: 2025-10-24 03:53:20 UTC  
> **Version**: 1.0.0 FINAL

---

## Overview

This guide covers setting up a **complete development environment** on a **single server** with all components from the production architecture, scaled down to minimal replicas.

---

## Hardware Requirements

### Recommended Single Server

```yaml
Purpose: Complete development environment for 10 developers

Hardware Specifications:
  CPU:
    Cores: 32 physical cores (64 threads)
    Model: AMD EPYC 7443P / Intel Xeon Gold 6338
    Clock: 2.85GHz base, 4.0GHz boost

  Memory:
    Size: 128GB DDR4 ECC
    Speed: 3200MHz
    Configuration: 8x 16GB DIMMs

  Storage:
    Primary:
      Type: NVMe SSD (PCIe 4.0)
      Size: 2TB
      Model: Samsung 980 Pro / WD Black SN850X
      IOPS: 1M+ read, 1M+ write

    Optional Secondary:
      Type: SATA SSD
      Size: 2TB
      Purpose: Backups, additional storage

  Network:
    Interface: 10Gbps Ethernet (dual port recommended)
    Model: Intel X550 / Mellanox ConnectX

  Power:
    PSU: 1000W 80+ Platinum
    UPS: 1500VA minimum (15-20 minutes runtime)

Cost Estimate: $8,000 - $12,000 USD
Lifespan: 5-7 years
```

### Minimum Hardware (Budget)

```yaml
Budget Option: Can work but not recommended

Hardware:
  CPU: 16 cores (AMD Ryzen 9 5950X)
  RAM: 64GB DDR4
  Storage: 1TB NVMe SSD
  Network: 1Gbps Ethernet

Cost: $3,000 - $5,000 USD
Limitations:
  - Only 5 developers
  - Slower builds
  - Cannot run all tools simultaneously
  - Limited testing capabilities
```

---

## Resource Allocation

### Complete Component List (Development Mode)

```yaml
Component Resource Allocation (All 1 Replica):

┌─────────────────────────────────────────────────────────────┐
│                   128GB RAM, 32 CPU CORES                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  INFRASTRUCTURE (16GB, 10 cores):                           │
│    - Kubernetes Control Plane:     8GB,  4 cores           │
│    - Cilium (eBPF CNI):             4GB,  2 cores           │
│    - Katran (L4 LB):                2GB,  2 cores           │
│    - Traefik (Ingress):             1GB,  1 core            │
│    - Varnish (Cache):               4GB,  2 cores           │
│                                                              │
│  DATABASES (48GB, 18 cores):                                │
│    - ScyllaDB:                     16GB,  8 cores           │
│    - DragonflyDB:                   8GB,  4 cores           │
│    - Redpanda:                      8GB,  4 cores           │
│    - ClickHouse:                   16GB,  4 cores           │
│                                                              │
│  STORAGE (8GB, 4 cores):                                    │
│    - MinIO (Object):                4GB,  2 cores           │
│    - Rook/Ceph (optional):          4GB,  2 cores           │
│                                                              │
│  OBSERVABILITY (26GB, 9 cores):                             │
│    - Prometheus:                    8GB,  4 cores           │
│    - Loki:                          4GB,  2 cores           │
│    - Tempo:                         4GB,  2 cores           │
│    - Grafana:                       2GB,  1 core            │
│                                                              │
│  DEVOPS TOOLS (36GB, 15 cores):                             │
│    - GitLab:                       16GB,  8 cores           │
│    - Argo CD:                       2GB,  1 core            │
│    - Harbor:                        8GB,  4 cores           │
│    - Vault:                         4GB,  2 cores           │
│                                                              │
│  APPLICATION SERVICES (16GB, 8 cores):                      │
│    - Actix API:                     8GB,  4 cores           │
│    - Zig-Zap API:                   4GB,  2 cores           │
│                                                              │
│  ADDITIONAL TOOLS (16GB, 8 cores):                          │
│    - Temporal:                      8GB,  4 cores           │
│    - Sentry:                        8GB,  4 cores           │
│    - Unleash:                       2GB,  1 core            │
│    - GrowthBook:                    2GB,  1 core            │
│    - Consul:                        4GB,  2 cores           │
│                                                              │
│  OS & OVERHEAD (8GB, 4 cores):                              │
│    - Linux kernel & system:         8GB,  4 cores           │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│  TOTAL ALLOCATED: 174GB RAM, 76 cores                       │
│  ACTUAL HARDWARE: 128GB RAM, 32 cores                       │
│  OVERCOMMIT RATIO: 1.36:1 RAM, 2.38:1 CPU                  │
└─────────────────────────────────────────────────────────────┘

Notes:
  - CPU overcommit is safe (most services idle)
  - RAM overcommit handled by swap (minimal usage)
  - Kubernetes manages resource allocation
  - Services scale down when idle
```

---

## Storage Layout

### Disk Partitioning

```bash
/dev/nvme0n1 (2TB NVMe SSD):

├─ /dev/nvme0n1p1  [512MB]   /boot/efi     (EFI System)
├─ /dev/nvme0n1p2  [100GB]   /             (Root filesystem)
├─ /dev/nvme0n1p3  [200GB]   /var/lib/scylla
├─ /dev/nvme0n1p4  [100GB]   /var/lib/redpanda
├─ /dev/nvme0n1p5  [150GB]   /var/lib/clickhouse
├─ /dev/nvme0n1p6  [200GB]   /var/lib/minio
├─ /dev/nvme0n1p7  [200GB]   /var/lib/gitlab
├─ /dev/nvme0n1p8  [200GB]   /var/lib/harbor
├─ /dev/nvme0n1p9  [150GB]   /var/lib/prometheus
├─ /dev/nvme0n1p10 [100GB]   /var/lib/loki
├─ /dev/nvme0n1p11 [50GB]    /var/lib/tempo
├─ /dev/nvme0n1p12 [200GB]   /var/lib/containerd
├─ /dev/nvme0n1p13 [32GB]    swap
└─ /dev/nvme0n1p14 [318GB]   /data          (General PVs)

Total: ~2TB

Recommended filesystem: ext4 or xfs
```

---

## Complete Installation Script

```bash name=install-complete-dev-environment.sh
#!/bin/bash
#
# Complete Development Environment Installation
# Single Server - All Components
#
# Author: @orazesen
# Date: 2025-10-24
# Version: 1.0.0 FINAL

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ${BLUE}INFO${NC}: $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ${YELLOW}WARN${NC}: $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ${RED}ERROR${NC}: $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_hardware() {
    local cpu_cores=$(nproc)
    local total_ram=$(free -g | awk '/^Mem:/{print $2}')

    log_info "Hardware Check:"
    echo "  CPU Cores: $cpu_cores"
    echo "  RAM: ${total_ram}GB"

    if [[ $cpu_cores -lt 16 ]]; then
        log_error "Minimum 16 CPU cores required (32 recommended)"
        exit 1
    fi

    if [[ $total_ram -lt 60 ]]; then
        log_error "Minimum 64GB RAM required (128GB recommended)"
        exit 1
    fi

    if [[ $cpu_cores -lt 32 ]]; then
        log_warn "32 cores recommended for best performance"
    fi

    if [[ $total_ram -lt 120 ]]; then
        log_warn "128GB RAM recommended for all features"
    fi
}

# Configuration
export DEBIAN_FRONTEND=noninteractive
K8S_VERSION="1.28.5"
CONTAINERD_VERSION="1.7.11"
HOSTNAME="dev-platform"
DOMAIN="dev.local"

log_info "Starting Complete Development Environment Installation"
log_info "Target: Single-node Kubernetes with full stack"

check_root
check_hardware

#############################################
# PHASE 1: System Preparation
#############################################

log_info "PHASE 1: System Preparation"

# Set hostname
hostnamectl set-hostname $HOSTNAME

# Update system
log_info "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install essential packages
log_info "Installing essential packages..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    git \
    vim \
    htop \
    iotop \
    sysstat \
    net-tools \
    jq \
    wget \
    unzip \
    build-essential \
    python3 \
    python3-pip

# Configure kernel parameters
log_info "Configuring kernel parameters..."
cat > /etc/sysctl.d/99-platform.conf <<EOF
# Network performance
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# Connection tracking
net.netfilter.nf_conntrack_max = 1048576

# Memory
vm.swappiness = 10
vm.overcommit_memory = 1
vm.max_map_count = 262144

# File descriptors
fs.file-max = 2097152
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 524288

# Kubernetes
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# Load kernel modules
log_info "Loading kernel modules..."
cat > /etc/modules-load.d/platform.conf <<EOF
overlay
br_netfilter
nf_conntrack
EOF

modprobe overlay
modprobe br_netfilter
modprobe nf_conntrack

# Configure swap (keep small swap for safety)
log_info "Configuring swap..."
if [[ $(swapon --show | wc -l) -gt 1 ]]; then
    swapoff -a
fi
# Keep swap in fstab but with low swappiness

#############################################
# PHASE 2: Container Runtime
#############################################

log_info "PHASE 2: Installing Container Runtime"

# Install containerd
log_info "Installing containerd ${CONTAINERD_VERSION}..."
curl -LO https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
tar Cxzvf /usr/local containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
rm containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz

# Install runc
curl -LO https://github.com/opencontainers/runc/releases/download/v1.1.10/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc
rm runc.amd64

# Install CNI plugins
mkdir -p /opt/cni/bin
curl -LO https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgz
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.4.0.tgz
rm cni-plugins-linux-amd64-v1.4.0.tgz

# Configure containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Create systemd service
cat > /etc/systemd/system/containerd.service <<'EOF'
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=1048576
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable containerd
systemctl start containerd

#############################################
# PHASE 3: Kubernetes Installation
#############################################

log_info "PHASE 3: Installing Kubernetes ${K8S_VERSION}"

# Add Kubernetes repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet=${K8S_VERSION}-00 kubeadm=${K8S_VERSION}-00 kubectl=${K8S_VERSION}-00
apt-mark hold kubelet kubeadm kubectl

# Configure kubelet
cat > /etc/default/kubelet <<EOF
KUBELET_EXTRA_ARGS=--max-pods=250
EOF

systemctl enable kubelet

# Initialize Kubernetes
log_info "Initializing Kubernetes cluster..."
kubeadm init \
    --kubernetes-version=${K8S_VERSION} \
    --pod-network-cidr=10.244.0.0/16 \
    --service-cidr=10.96.0.0/16 \
    --node-name=$HOSTNAME

# Configure kubectl
export KUBECONFIG=/etc/kubernetes/admin.conf
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /root/.bashrc

mkdir -p /home/orazesen/.kube
cp /etc/kubernetes/admin.conf /home/orazesen/.kube/config
chown -R orazesen:orazesen /home/orazesen/.kube

# Allow scheduling on control plane
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

#############################################
# PHASE 4: Cilium Installation
#############################################

log_info "PHASE 4: Installing Cilium (eBPF CNI)"

# Install Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz{,.sha256sum}

# Install Cilium
cilium install \
    --version 1.14.5 \
    --set kubeProxyReplacement=strict

cilium status --wait

#############################################
# PHASE 5: Helm Installation
#############################################

log_info "PHASE 5: Installing Helm"

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Add Helm repositories
log_info "Adding Helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add harbor https://helm.goharbor.io
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add jetstack https://charts.jetstack.io
helm repo add traefik https://helm.traefik.io/traefik
helm repo update

#############################################
# PHASE 6: Storage Setup
#############################################

log_info "PHASE 6: Setting up storage"

# Install local-path-provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

#############################################
# PHASE 7: Create Namespaces
#############################################

log_info "PHASE 7: Creating namespaces"

kubectl create namespace monitoring || true
kubectl create namespace scylla || true
kubectl create namespace dragonfly || true
kubectl create namespace redpanda || true
kubectl create namespace storage || true
kubectl create namespace gitlab || true
kubectl create namespace argocd || true
kubectl create namespace harbor || true
kubectl create namespace vault || true
kubectl create namespace traefik || true
kubectl create namespace services || true
kubectl create namespace sentry || true
kubectl create namespace temporal || true
kubectl create namespace unleash || true
kubectl create namespace database || true

#############################################
# PHASE 8: Core Infrastructure
#############################################

log_info "PHASE 8: Installing core infrastructure"

# cert-manager
log_info "Installing cert-manager..."
kubectl create namespace cert-manager || true
helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --set installCRDs=true \
    --set resources.requests.cpu=100m \
    --set resources.requests.memory=128Mi \
    --wait

# Traefik
log_info "Installing Traefik..."
helm install traefik traefik/traefik \
    --namespace traefik \
    --set deployment.replicas=0 \
    --set resources.requests.cpu=1 \
    --set resources.requests.memory=1Gi \
    --set resources.limits.cpu=2 \
    --set resources.limits.memory=2Gi \
    --wait

#############################################
# PHASE 9: Storage Layer
#############################################

log_info "PHASE 9: Installing storage layer"

# MinIO
log_info "Installing MinIO..."
helm install minio bitnami/minio \
    --namespace storage \
    --set auth.rootUser=admin \
    --set auth.rootPassword=minio-dev-password \
    --set persistence.size=200Gi \
    --set resources.requests.cpu=2 \
    --set resources.requests.memory=4Gi \
    --wait

#############################################
# PHASE 10: Databases
#############################################

log_info "PHASE 10: Installing databases"

# DragonflyDB
log_info "Installing DragonflyDB..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dragonfly
  namespace: dragonfly
spec:
  replicas: 0
  selector:
    matchLabels:
      app: dragonfly
  template:
    metadata:
      labels:
        app: dragonfly
    spec:
      containers:
      - name: dragonfly
        image: docker.dragonflydb.io/dragonflydb/dragonfly:v1.13.0
        args:
        - "--maxmemory=6G"
        - "--proactor_threads=4"
        ports:
        - containerPort: 6379
        resources:
          requests:
            cpu: "2"
            memory: 4Gi
          limits:
            cpu: "4"
            memory: 8Gi
---
apiVersion: v1
kind: Service
metadata:
  name: dragonfly
  namespace: dragonfly
spec:
  ports:
  - port: 6379
  selector:
    app: dragonfly
EOF

# ClickHouse
log_info "Installing ClickHouse..."
helm install clickhouse bitnami/clickhouse \
    --namespace database \
    --set auth.password=clickhouse \
    --set persistence.size=150Gi \
    --set resources.requests.cpu=4 \
    --set resources.requests.memory=16Gi \
    --set resources.limits.cpu=8 \
    --set resources.limits.memory=32Gi \
    --wait

#############################################
# PHASE 11: Observability Stack
#############################################

log_info "PHASE 11: Installing observability stack"

# Prometheus Stack (includes Grafana)
log_info "Installing Prometheus + Grafana..."
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --set prometheus.prometheusSpec.retention=7d \
    --set prometheus.prometheusSpec.resources.requests.cpu=4 \
    --set prometheus.prometheusSpec.resources.requests.memory=8Gi \
    --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=100Gi \
    --set grafana.adminPassword=admin \
    --set grafana.resources.requests.cpu=1 \
    --set grafana.resources.requests.memory=2Gi \
    --wait

# Loki
log_info "Installing Loki..."
helm install loki grafana/loki-stack \
    --namespace monitoring \
    --set loki.persistence.enabled=true \
    --set loki.persistence.size=50Gi \
    --set loki.resources.requests.cpu=2 \
    --set loki.resources.requests.memory=4Gi \
    --wait

#############################################
# PHASE 12: DevOps Tools
#############################################

log_info "PHASE 12: Installing DevOps tools"

# Argo CD
log_info "Installing Argo CD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Vault
log_info "Installing Vault..."
helm install vault hashicorp/vault \
    --namespace vault \
    --set server.dev.enabled=true \
    --set server.resources.requests.cpu=2 \
    --set server.resources.requests.memory=4Gi \
    --wait

#############################################
# Completion
#############################################

log_info "════════════════════════════════════════════════════════════"
log_info "✓ Installation Complete!"
log_info "════════════════════════════════════════════════════════════"
echo ""
log_info "Cluster Information:"
echo "  - Kubernetes: ${K8S_VERSION}"
echo "  - CNI: Cilium (eBPF)"
echo "  - Node: ${HOSTNAME}"
echo ""
log_info "Access Grafana:"
echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
echo "  URL: http://localhost:3000"
echo "  User: admin / admin"
echo ""
log_info "Access Argo CD:"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "  kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "  URL: https://localhost:8080"
echo "  User: admin / ${ARGOCD_PASSWORD}"
echo ""
log_info "Next steps:"
echo "  1. Install remaining components (see documentation)"
echo "  2. Deploy your applications"
echo "  3. Configure monitoring dashboards"
echo ""
log_info "For help: https://github.com/orazesen/platform-docs"
```

---

## Post-Installation Steps

### 1. Verify Installation

```bash
# Check all pods are running
kubectl get pods -A

# Check node status
kubectl get nodes

# Check resources
kubectl top nodes
kubectl top pods -A
```

### 2. Install Remaining Components

See `DEVOPS_TOOLS.md` for:

- GitLab installation
- Harbor registry
- Temporal workflows
- Sentry error tracking
- Feature flags (Unleash)
- A/B testing (GrowthBook)

### 3. Configure DNS/Hosts

```bash
# Add to /etc/hosts on your laptop
10.0.0.10  grafana.dev.local
10.0.0.10  argocd.dev.local
10.0.0.10  gitlab.dev.local
10.0.0.10  harbor.dev.local
10.0.0.10  api.dev.local
```

### 4. Deploy Sample Application

```bash
# Create deployment
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Check service
kubectl get svc nginx
```

---

## Monitoring & Management

### Resource Monitoring

```bash
# Watch cluster resources
watch kubectl top nodes

# Monitor specific namespace
kubectl top pods -n services

# Check disk usage
df -h

# Check memory
free -h
```

### Useful Commands

```bash
# Scale deployment
kubectl scale deployment <name> --replicas=0

# Get logs
kubectl logs -f <pod-name>

# Execute in pod
kubectl exec -it <pod-name> -- /bin/bash

# Port forward
kubectl port-forward svc/<service> <local-port>:<remote-port>

# Delete all in namespace
kubectl delete all --all -n <namespace>
```

---

## Troubleshooting

### Common Issues

```yaml
Issue: Pods stuck in Pending
Cause: Insufficient resources
Fix:
  - Check: kubectl describe pod <pod-name>
  - Reduce resource requests
  - Scale down other services

Issue: Out of Memory
Cause: Too many services running
Fix:
  - Increase swap: sudo swapon --show
  - Stop unused services
  - Reduce replica counts

Issue: Disk Full
Cause: Container images, logs
Fix:
  - Clean images: docker system prune -a
  - Clean logs: journalctl --vacuum-time=3d
  - Check disk: du -sh /*

Issue: High CPU
Cause: Background processes
Fix:
```
