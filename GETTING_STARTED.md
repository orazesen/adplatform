# 🚀 Getting Started with AdPlatform

## 📋 Overview

AdPlatform gives you **two production-ready systems in one**:

1. **Ultra-High-Performance Ad Platform** - 5B+ RPS capability with Seastar C++ and Glommio Rust
2. **Complete DevOps Platform** - GitLab, monitoring, data engineering, ML platform (fully automated)

Choose your path based on your goal:

- **Path A:** Deploy the DevOps platform first (recommended for most)
- **Path B:** Deploy the complete ad platform infrastructure (for production deployment)

---

## 🎯 Path A: DevOps Platform (Recommended - 60 minutes)

**Perfect for:** Development teams who want a complete platform for building services

### Quick Start (3 Commands)

```bash
# 1. Configure (5 min)
./scripts/configure-platform.sh

# 2. Deploy infrastructure (30 min)
make deploy-all ENV=production

# 3. Deploy platform (30 min)
make deploy-platform ENV=production

# ✅ Done! Access at: https://gitlab.yourdomain.com
```

### What You Get

After deployment, you'll have:

#### Development Tools

- ✅ **GitLab CE** - Git repos, CI/CD pipelines, container registry
- ✅ **GitLab Runners** - Auto-scaling Kubernetes executors
- ✅ **Auto-Deployment** - Push code → automatic deployment

#### Monitoring & Observability

- ✅ **Grafana** - Metrics dashboards (https://grafana.yourdomain.com)
- ✅ **Prometheus** - Metrics collection & alerting
- ✅ **Loki** - Centralized log aggregation
- ✅ **Jaeger** - Distributed request tracing
- ✅ **AlertManager** - Alert routing & management

#### Data Engineering Platform

- ✅ **Apache Airflow** - Workflow orchestration
- ✅ **Apache Spark** - Distributed data processing
- ✅ **JupyterHub** - Multi-user notebook environment
- ✅ **PostgreSQL** - Metadata storage

#### ML Platform

- ✅ **MLflow** - Experiment tracking & model registry
- ✅ **Kubeflow Pipelines** - ML workflow automation
- ✅ **Model Serving** - Deploy trained models

#### Security & Infrastructure

- ✅ **HashiCorp Vault** - Secrets management
- ✅ **cert-manager** - Automatic TLS certificates
- ✅ **Linkerd** - Service mesh with mTLS
- ✅ **K3s Kubernetes** - Lightweight orchestration

### Detailed Steps

#### Step 1: Prerequisites

**Hardware Requirements:**

- 3 servers (bare metal or VMs)
- 8+ cores, 32GB RAM minimum per server
- 100GB+ disk space
- Ubuntu 22.04 LTS (recommended)

**Network Requirements:**

- Domain name for SSL certificates
- Ports: 80, 443, 6443 (Kubernetes API)

**Local Machine:**

```bash
# Install required tools
brew install terraform ansible kubectl helm yq  # macOS
# or
sudo apt install terraform ansible kubectl helm  # Ubuntu
```

#### Step 2: Configure Platform

```bash
# Interactive configuration wizard
./scripts/configure-platform.sh
```

This creates `platform-config.yaml` with:

- Domain name (e.g., example.com)
- Admin email for SSL certificates
- GitLab configuration
- Resource limits
- Component selection

#### Step 3: Deploy Infrastructure

```bash
# Deploy to production
make deploy-all ENV=production

# Or deploy to staging first
make deploy-all ENV=staging
```

**What happens:**

1. **Terraform** provisions servers (30 min)

   - Creates VMs/bare metal config
   - Sets up networking
   - Configures firewalls

2. **Ansible** configures servers (15 min)

   - Installs packages
   - Tunes kernel
   - Sets up K3s cluster

3. **Helm** deploys platform (15 min)
   - Installs all components
   - Configures ingress
   - Sets up TLS certificates

#### Step 4: Deploy Platform Components

```bash
# Deploy all platform components
make deploy-platform ENV=production

# Or deploy selectively:
make deploy-base-platform ENV=production      # GitLab + Monitoring
make deploy-data-platform ENV=production      # Airflow + Spark
make deploy-ml-platform ENV=production        # MLflow + Kubeflow
```

#### Step 5: Setup CI/CD Auto-Deployment

```bash
# One-time setup (10 min)
./scripts/setup-gitlab-templates.sh
```

This creates:

- 3 project templates (Rust, Seastar C++, Python)
- GitLab CI/CD pipelines
- Auto-deployment to Kubernetes
- Monitoring dashboard creation

#### Step 6: Start Developing!

```bash
# Clone a template
git clone https://gitlab.yourdomain.com/templates/rust-service-template.git my-service

# Write your code
cd my-service
# ... make changes ...

# Push → Auto-deploy!
git push

# ✅ Service live in 5-10 min at https://my-service.yourdomain.com
```

### Access Your Platform

After deployment, access these services:

```bash
# Get URLs and credentials
make platform-info ENV=production
```

**Default URLs:**

- GitLab: https://gitlab.yourdomain.com
- Grafana: https://grafana.yourdomain.com
- Airflow: https://airflow.yourdomain.com
- JupyterHub: https://jupyter.yourdomain.com
- MLflow: https://mlflow.yourdomain.com

**Default Credentials:**

- Username: `admin`
- Password: Set in `platform-config.yaml`

### Troubleshooting

```bash
# Check platform health
make validate ENV=production

# View logs
make logs ENV=production

# Check pod status
kubectl get pods -A

# Restart a component
kubectl rollout restart deployment/gitlab -n gitlab
```

---

## 🏗️ Path B: Complete Ad Platform (Production - 2-3 hours)

**Perfect for:** Deploying the full high-performance ad serving infrastructure

### Architecture Overview

**Hot Paths** (Seastar C++ - 6M RPS/core):

- Ad serving engine
- Real-time bidding
- Analytics ingestion

**Control Plane** (Glommio Rust - 1.1M RPS/core):

- Campaign management
- User management
- Billing & reporting
- Authentication

**Data Layer**:

- **ScyllaDB** - Campaign & user data (10x faster than Cassandra)
- **ClickHouse** - Analytics & reporting (100x faster than PostgreSQL)
- **Redpanda** - Event streaming (10x faster than Kafka)
- **DragonflyDB** - Caching (25x faster than Redis)

**Load Balancing**:

- **Katran** (Meta OSS) - L4 load balancer (100M pps)
- **Envoy** - L7 load balancer (1M RPS)
- **XDP/eBPF** - DDoS protection (100M pps)

### Prerequisites

**Hardware Requirements (Minimum Production):**

- 3 servers for control plane (32+ cores, 128GB RAM, NVMe)
- 3+ servers for data layer (64+ cores, 256GB RAM, NVMe)
- 2 servers for edge (L4/L7 load balancers)

**OS:** Ubuntu 22.04 LTS with kernel >= 5.15

### Quick Deployment

```bash
# 1. Deploy infrastructure (60 min)
make deploy-all ENV=production

# 2. Deploy data plane (30 min)
make deploy-dataplane ENV=production

# 3. Configure platform (30 min)
./scripts/configure-platform.sh
make deploy-platform ENV=production

# 4. Build & deploy services (30 min)
# Seastar services
make build-seastar
# Glommio services
make build-rust

# 5. Validate
make validate ENV=production
make test-load ENV=production
```

### Detailed Production Setup

#### 1. Prepare Servers (Each Node)

```bash
# Create deploy user
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG sudo,docker deploy

# Install build tools
sudo apt update && sudo apt install -y \
  build-essential cmake ninja-build git curl \
  libnuma-dev libhwloc-dev libssl-dev libboost-all-dev \
  pkg-config docker.io linux-headers-$(uname -r)
```

#### 2. Kernel Tuning (Critical for Performance)

```bash
# Add to /etc/sysctl.d/99-adplatform.conf
cat <<EOF | sudo tee /etc/sysctl.d/99-adplatform.conf
vm.swappiness = 1
vm.overcommit_memory = 1
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
EOF

# Apply
sudo sysctl --system
```

#### 3. Huge Pages Setup

```bash
# Add to /etc/default/grub
GRUB_CMDLINE_LINUX="hugepagesz=2M hugepages=4096 default_hugepagesz=2M"

# Update grub and reboot
sudo update-grub
sudo reboot
```

#### 4. Deploy Data Plane

```bash
# Deploy databases
kubectl create namespace scylla
kubectl create namespace streaming
kubectl create namespace analytics
kubectl create namespace cache

# ScyllaDB
helm install scylla scylla/scylla -n scylla \
  --set resources.requests.cpu=16 \
  --set resources.requests.memory=64Gi

# Redpanda
helm install redpanda redpanda/redpanda -n streaming \
  --set resources.requests.cpu=8 \
  --set resources.requests.memory=32Gi

# ClickHouse
helm install clickhouse clickhouse/clickhouse -n analytics \
  --set resources.requests.cpu=16 \
  --set resources.requests.memory=64Gi

# DragonflyDB
helm install dragonfly dragonfly/dragonfly -n cache \
  --set resources.requests.cpu=8 \
  --set resources.requests.memory=16Gi
```

#### 5. Deploy Load Balancers

```bash
# Envoy (L7)
kubectl apply -f deploy/envoy/envoy-gateway.yaml

# Katran (L4) - on edge nodes
# Build from source or use prebuilt binaries
```

#### 6. Build Seastar Services

```bash
# Clone and build
cd services/ad-serving
mkdir build && cd build
cmake -GNinja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_FLAGS="-march=native -O3" ..
ninja

# Deploy with CPU pinning
kubectl apply -f deploy/ad-serving-deployment.yaml
```

#### 7. Build Glommio Services

```bash
# Build
cd services/campaign-mgmt
cargo build --release

# Create Docker image
docker build -t registry.yourdomain.com/campaign-mgmt:latest .
docker push registry.yourdomain.com/campaign-mgmt:latest

# Deploy
kubectl apply -f deploy/campaign-mgmt-deployment.yaml
```

#### 8. Performance Validation

```bash
# Load test ad serving (expect 1M+ RPS per pod)
wrk -t8 -c100 -d30s http://ad-serving.yourdomain.com/ad

# Check metrics
curl http://ad-serving.yourdomain.com/metrics

# View Grafana dashboards
open https://grafana.yourdomain.com
```

### Performance Expectations

**Seastar Services:**

- Ad Serving: 1-6M RPS per core
- Bidding Engine: 500K-2M RPS per core
- Analytics Ingest: 2-4M events/sec per core

**Glommio Services:**

- Campaign API: 100K-1M RPS per core
- User Management: 100K-500K RPS per core
- Auth Service: 200K-800K RPS per core

**Databases:**

- ScyllaDB: 1M+ ops/sec per node
- ClickHouse: 1-5M rows/sec ingestion
- Redpanda: 10M+ msgs/sec
- DragonflyDB: 4M+ ops/sec

---

## 📚 Next Steps

### Learn More

- **[README.md](README.md)** - Project overview
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture
- **[TECH_STACK.md](TECH_STACK.md)** - Complete technology stack
- **[ROADMAP.md](ROADMAP.md)** - Development roadmap

### CI/CD & Deployment

- **[CICD_QUICKSTART.md](CICD_QUICKSTART.md)** - CI/CD quick start
- **[CICD_COMPLETE_GUIDE.md](CICD_COMPLETE_GUIDE.md)** - Complete CI/CD guide

### Operations

- **[SCRIPTS_CLEANUP_SUMMARY.md](SCRIPTS_CLEANUP_SUMMARY.md)** - Available scripts
- **[YAML_CLEANUP_SUMMARY.md](YAML_CLEANUP_SUMMARY.md)** - Ansible playbooks

---

## 🆘 Support

### Common Issues

**Deployment fails:**

```bash
# Check logs
kubectl logs -f deployment/gitlab -n gitlab

# Validate configuration
./scripts/validate-deployment.sh production
```

**Performance issues:**

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -A

# View metrics
make platform-status ENV=production
```

**Network issues:**

```bash
# Check ingress
kubectl get ingress -A

# Check certificates
kubectl get certificates -A
```

### Getting Help

1. Check [ARCHITECTURE.md](ARCHITECTURE.md) for design decisions
2. Review [TECH_STACK.md](TECH_STACK.md) for component details
3. See [ANALYSIS_AND_IMPROVEMENTS.md](ANALYSIS_AND_IMPROVEMENTS.md) for optimization tips

---

## ✅ Success Checklist

### DevOps Platform Deployed

- [ ] GitLab accessible and CI/CD working
- [ ] Grafana showing metrics
- [ ] Airflow DAGs running
- [ ] JupyterHub notebooks working
- [ ] Auto-deployment from git push works

### Ad Platform Deployed

- [ ] All pods running (ScyllaDB, Redpanda, ClickHouse, DragonflyDB)
- [ ] Seastar services responding
- [ ] Glommio services responding
- [ ] Load balancers distributing traffic
- [ ] Performance tests passing (1M+ RPS)
- [ ] Monitoring dashboards populated

**Congratulations! Your platform is ready! 🎉**
