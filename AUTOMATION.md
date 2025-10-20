# 🤖 Platform Automation Guide

## Overview

Complete automation for **infrastructure provisioning**, **platform deployment**, and **CI/CD pipelines**.

**Status:** ✅ **100% Automated** - From bare metal to production in 60 minutes

---

## 🎯 What's Automated

### Layer 1: Infrastructure (Terraform + Ansible)

✅ **Multi-cloud provisioning** - Hetzner, AWS, GCP, Azure, OVH, bare-metal  
✅ **Server configuration** - Kernel tuning, packages, users  
✅ **Kubernetes cluster** - K3s + Cilium CNI  
✅ **Networking** - Firewalls, load balancers, DNS  
✅ **Storage** - Persistent volumes, NVMe optimization

### Layer 2: Platform (Helm + Scripts)

✅ **GitLab CE** - Git + CI/CD + Container Registry  
✅ **Monitoring** - Prometheus, Grafana, Loki, Jaeger  
✅ **Data Engineering** - Airflow, Spark, JupyterHub  
✅ **ML Platform** - MLflow, Kubeflow Pipelines  
✅ **Security** - Vault, cert-manager, Linkerd

### Layer 3: CI/CD Auto-Deployment

✅ **GitLab templates** - Rust, Seastar C++, Python  
✅ **Pipeline automation** - Build, test, deploy, monitor  
✅ **Auto-scaling** - HPA based on CPU/memory  
✅ **Auto-monitoring** - Grafana dashboards  
✅ **Auto-TLS** - Let's Encrypt certificates

---

## 🚀 Quick Start

### Full Stack Deployment (60 min)

```bash
# 1. Configure (5 min)
./scripts/configure-platform.sh

# 2. Deploy infrastructure (30 min)
make deploy-all ENV=production

# 3. Deploy platform (30 min)
make deploy-platform ENV=production

# 4. Setup CI/CD (10 min)
./scripts/setup-gitlab-templates.sh

# ✅ Done! Platform ready at https://gitlab.yourdomain.com
```

### Individual Components

```bash
# Infrastructure only
make deploy-infra ENV=production     # Terraform: provision servers
make deploy-config ENV=production    # Ansible: configure servers

# Platform components
make deploy-base-platform ENV=production    # GitLab + Monitoring
make deploy-data-platform ENV=production    # Airflow + Spark
make deploy-ml-platform ENV=production      # MLflow + Kubeflow

# Validation
make validate ENV=production         # Health checks
```

---

## 📋 Layer 1: Infrastructure Automation

### Architecture

```
Terraform → Provisions servers on any provider
    ↓
Ansible → Configures OS, installs packages, tunes kernel
    ↓
K3s → Deploys lightweight Kubernetes cluster
    ↓
Cilium → eBPF-based networking and load balancing
```

### Supported Providers

| Provider       | Status      | Deploy Time | Notes                                |
| -------------- | ----------- | ----------- | ------------------------------------ |
| **Hetzner**    | ✅ Complete | 20 min      | Recommended (best price/performance) |
| **OVH**        | ✅ Complete | 25 min      | Bare metal option                    |
| **AWS**        | ✅ Template | 30 min      | Template ready, customize as needed  |
| **GCP**        | ✅ Template | 30 min      | Template ready, customize as needed  |
| **Azure**      | ✅ Template | 30 min      | Template ready, customize as needed  |
| **Bare Metal** | ✅ Complete | 15 min      | Fastest (no provisioning overhead)   |

### Configuration

Edit `environments/production.tfvars`:

```hcl
# Provider
provider = "hetzner"  # or: aws, gcp, azure, ovh

# Cluster size
control_plane_count = 3
worker_count = 3

# Server specs
control_plane_instance_type = "cx41"  # 8 vCPU, 32GB RAM
worker_instance_type = "cx51"         # 16 vCPU, 64GB RAM

# Networking
region = "nbg1"  # Nuremberg
ssh_keys = ["ssh-rsa AAAA..."]
```

### Commands

```bash
# Full deployment
make deploy-all ENV=production

# Step-by-step
make deploy-infra ENV=production   # Terraform
make deploy-config ENV=production  # Ansible
make deploy-apps ENV=production    # Applications

# Dry run (preview changes)
DRY_RUN=true make deploy-all ENV=production

# Destroy (DANGEROUS!)
make destroy ENV=production
```

### Zero-Downtime Migration

Move between providers with zero downtime:

```bash
# Backup current provider
./scripts/backup-all.sh hetzner production

# Provision new provider
./scripts/migrate-infra.sh hetzner aws production

# Process:
# 1. Backup all data from source
# 2. Provision new infrastructure
# 3. Restore data to target
# 4. Run parallel validation
# 5. Switch DNS (zero downtime)
# 6. Decommission source
```

---

## 📋 Layer 2: Platform Automation

### What Gets Deployed

```bash
# Base Platform (25 min)
- GitLab CE (git, CI/CD, container registry)
- cert-manager (auto TLS certificates)
- Nginx Ingress (HTTPS routing)
- Prometheus + Grafana (metrics)
- Loki (logs)
- Jaeger (tracing)

# Data Engineering (10 min)
- Apache Airflow (workflow orchestration)
- Apache Spark (data processing)
- JupyterHub (notebooks)
- PostgreSQL (metadata)

# ML Platform (10 min)
- MLflow (experiment tracking)
- Kubeflow Pipelines (ML workflows)
- Model registry

# Security (5 min)
- HashiCorp Vault (secrets)
- Linkerd (service mesh)
- Network policies
```

### Configuration

Edit `platform-config.yaml`:

```yaml
platform:
  domain: example.com
  email: admin@example.com
  environment: production

gitlab:
  version: "16.5.0"
  admin:
    username: root
    password: CHANGE_ME

  runners:
    concurrent: 10

  registry:
    enabled: true

monitoring:
  grafana:
    admin_password: CHANGE_ME

  prometheus:
    retention: 30d
    storage: 100Gi

data_engineering:
  airflow:
    enabled: true
    workers: 3

  spark:
    enabled: true
    master_count: 1
    worker_count: 3

ml_platform:
  mlflow:
    enabled: true

  kubeflow:
    enabled: true
```

### Commands

```bash
# Full platform
./scripts/configure-platform.sh         # Interactive config wizard
make deploy-platform ENV=production     # Deploy everything

# Selective deployment
make deploy-base-platform ENV=production    # GitLab + Monitoring only
make deploy-data-platform ENV=production    # Data engineering only
make deploy-ml-platform ENV=production      # ML platform only

# Platform info
make platform-info ENV=production       # Get URLs and credentials
make platform-status ENV=production     # Check health
```

### Platform URLs

After deployment:

```
GitLab:      https://gitlab.example.com
Grafana:     https://grafana.example.com
Airflow:     https://airflow.example.com
JupyterHub:  https://jupyter.example.com
MLflow:      https://mlflow.example.com
Vault:       https://vault.example.com
```

---

## 📋 Layer 3: CI/CD Auto-Deployment

### Setup (One-Time)

```bash
./scripts/setup-gitlab-templates.sh
```

**What it creates:**

- 3 project templates (Rust, Seastar C++, Python)
- GitLab CI/CD pipelines (build → test → deploy → monitor)
- Kubernetes deployment configurations
- Helm charts for services
- Grafana dashboard templates

**Runtime:** ~10 minutes

### Developer Workflow

```bash
# 1. Clone template
git clone https://gitlab.example.com/templates/rust-service-template.git my-service

# 2. Write code
cd my-service
vim src/main.rs

# 3. Push code
git add .
git commit -m "Add feature"
git push

# 4. Auto-deployment happens!
# - Build: Compile code (2-5 min)
# - Test: Run tests (30s-2 min)
# - Deploy: Kubernetes deployment (2-3 min)
# - Monitor: Create Grafana dashboard (30s)

# ✅ Service live at: https://my-service.example.com (5-10 min total)
```

### Pipeline Stages

```yaml
stages:
  - build # Compile + Docker image
  - test # Unit + integration tests
  - deploy # Kubernetes deployment
  - monitor # Grafana dashboard
```

**Rust Service Pipeline:**

```bash
build:
  - cargo build --release
  - docker build -t registry/service:latest .
  - docker push registry/service:latest

test:
  - cargo test --release

deploy:
  - helm upgrade --install service ./chart
  - kubectl rollout status deployment/service

monitor:
  - Create Grafana dashboard via API
```

**Seastar C++ Pipeline:**

```bash
build:
  - cmake -DCMAKE_BUILD_TYPE=Release
  - ninja
  - docker build --build-arg BUILD=release .

test:
  - ./build/test_suite
  - ./build/benchmark --duration=10s  # Expect 1M+ RPS

deploy:
  - Deploy with CPU pinning + hostNetwork
  - Scale 10-100 replicas

monitor:
  - Performance dashboard
```

### Auto-Scaling Configuration

```yaml
# Rust services
autoscaling:
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# Seastar services (high performance)
autoscaling:
  minReplicas: 10
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80
```

### Auto-Monitoring

Each service gets:

- ✅ Prometheus metrics scraping
- ✅ Grafana dashboard (auto-created)
- ✅ Log aggregation (Loki)
- ✅ Distributed tracing (Jaeger)
- ✅ Alerting rules

---

## 🔧 Advanced Automation

### Blue-Green Deployment

```bash
# Deploy new version to "green"
./scripts/deploy-blue-green.sh green production

# Validate
./scripts/validate-deployment.sh green

# Switch traffic
./scripts/switch-traffic.sh green

# Rollback if needed
./scripts/switch-traffic.sh blue
```

### Multi-Region Deployment

```bash
./scripts/deploy-multi-region.sh \
  --regions "us-east-1,eu-west-1,ap-southeast-1" \
  --env production
```

### Disaster Recovery

```bash
# Backup (runs automatically daily)
./scripts/backup-all.sh production

# Restore
./scripts/restore-all.sh production 2024-01-15
```

---

## 📊 Automation Status

### Infrastructure Layer ✅ 100%

- [x] Multi-cloud Terraform modules
- [x] Ansible playbooks (bootstrap, K3s)
- [x] Kubernetes cluster automation
- [x] Master orchestration script
- [x] Migration automation

### Platform Layer ✅ 100%

- [x] GitLab deployment
- [x] Monitoring stack (Prometheus, Grafana, Loki, Jaeger)
- [x] Data engineering (Airflow, Spark, Jupyter)
- [x] ML platform (MLflow, Kubeflow)
- [x] Security (Vault, cert-manager, Linkerd)

### CI/CD Layer ✅ 100%

- [x] Project templates (Rust, C++, Python)
- [x] GitLab pipelines
- [x] Auto-deployment to Kubernetes
- [x] Auto-scaling configuration
- [x] Auto-monitoring setup
- [x] Auto-TLS provisioning

### Data Plane ⚠️ 50%

- [x] Deployment scripts
- [ ] Helm values files (ScyllaDB, Redpanda, ClickHouse, DragonflyDB)
- [ ] Performance tuning roles

---

## 🎯 Performance Expectations

### Deployment Times

| Task                  | Duration      | Parallelizable     |
| --------------------- | ------------- | ------------------ |
| Terraform provision   | 15-20 min     | ❌                 |
| Ansible configuration | 10-15 min     | ✅ (per server)    |
| K8s cluster ready     | 5 min         | ❌                 |
| Platform deployment   | 20-30 min     | ✅ (per component) |
| CI/CD setup           | 10 min        | ❌                 |
| **Total (serial)**    | **60-80 min** |                    |
| **Total (parallel)**  | **40-50 min** |                    |

### Pipeline Performance

| Language    | Build   | Test      | Deploy  | Total    |
| ----------- | ------- | --------- | ------- | -------- |
| Rust        | 2-5 min | 30s-2 min | 2-3 min | 5-10 min |
| Seastar C++ | 3-8 min | 1-3 min   | 2-3 min | 6-14 min |
| Python      | 1-2 min | 30s-1 min | 2-3 min | 4-6 min  |

---

## 🆘 Troubleshooting

### Deployment Fails

```bash
# Check logs
kubectl logs -f deployment/gitlab -n gitlab

# Validate configuration
./scripts/validate-deployment.sh production

# Check resource usage
kubectl top nodes
kubectl top pods -A
```

### Platform Not Accessible

```bash
# Check ingress
kubectl get ingress -A

# Check certificates
kubectl get certificates -A

# Check DNS
nslookup gitlab.example.com
```

### CI/CD Pipeline Fails

```bash
# Check GitLab runners
kubectl get pods -n gitlab-runners

# Check runner logs
kubectl logs -f -n gitlab-runners -l app=gitlab-runner

# Re-register runners
./scripts/setup-gitlab-templates.sh
```

---

## 📚 Related Documentation

- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Step-by-step deployment guide
- **[CICD_QUICKSTART.md](CICD_QUICKSTART.md)** - CI/CD quick start
- **[CICD_COMPLETE_GUIDE.md](CICD_COMPLETE_GUIDE.md)** - Complete CI/CD guide
- **[TECH_STACK.md](TECH_STACK.md)** - Technology stack details
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture

---

## ✅ Automation Checklist

### Initial Setup

- [ ] Configure platform (`./scripts/configure-platform.sh`)
- [ ] Deploy infrastructure (`make deploy-all ENV=production`)
- [ ] Deploy platform (`make deploy-platform ENV=production`)
- [ ] Setup CI/CD (`./scripts/setup-gitlab-templates.sh`)
- [ ] Validate deployment (`make validate ENV=production`)

### Verify Platform

- [ ] GitLab accessible and functional
- [ ] Grafana showing metrics
- [ ] Airflow DAGs running
- [ ] CI/CD pipelines working
- [ ] Auto-deployment from git push works

### Production Ready

- [ ] TLS certificates issued
- [ ] Monitoring alerts configured
- [ ] Backup automation enabled
- [ ] Disaster recovery tested
- [ ] Multi-region configured (if needed)

**Congratulations! Your platform is fully automated! 🎉**
