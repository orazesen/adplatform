# Infrastructure Automation Guide - Deploy Anywhere

## Overview

This guide provides complete Infrastructure-as-Code (IaC) to deploy the entire AdPlatform stack to any location (bare-metal, cloud, hybrid) with a single command.

## Architecture Layers

```
1. Infrastructure Provisioning (Terraform)
   └─> Bare-metal, AWS, GCP, Azure, Hetzner, OVH

2. OS Configuration (Ansible)
   └─> Kernel tuning, packages, users, security

3. Kubernetes Setup (k3s + Cilium)
   └─> Container orchestration

4. Data Plane (Helm)
   └─> ScyllaDB, Redpanda, DragonflyDB, ClickHouse, MinIO

5. Application Deployment (Helm + Systemd)
   └─> Seastar services, Glommio services

6. Monitoring (Helm)
   └─> Prometheus, Grafana, Loki, Jaeger
```

## Quick Start (Deploy Anywhere)

```bash
# 1. Configure your target infrastructure
cp environments/example.tfvars environments/production.tfvars
vim environments/production.tfvars

# 2. ONE COMMAND DEPLOYMENT
make deploy-all ENV=production

# That's it! Full stack deployed in ~30 minutes
```

## Directory Structure

```
adplatform/
├── terraform/                    # Infrastructure provisioning
│   ├── modules/
│   │   ├── bare-metal/          # Bare-metal via IPMI/iLO
│   │   ├── aws/                 # AWS EC2
│   │   ├── gcp/                 # GCP Compute
│   │   ├── hetzner/             # Hetzner dedicated
│   │   └── ovh/                 # OVH dedicated
│   ├── main.tf
│   └── variables.tf
│
├── ansible/                      # Configuration management
│   ├── playbooks/
│   │   ├── 01-bootstrap.yml     # Initial setup
│   │   ├── 02-kernel-tuning.yml # Performance tuning
│   │   ├── 03-k3s-install.yml   # Kubernetes
│   │   └── 04-monitoring.yml    # Observability
│   ├── roles/
│   │   ├── kernel-tuning/
│   │   ├── hugepages/
│   │   ├── cpu-governor/
│   │   ├── network-tuning/
│   │   └── security-hardening/
│   └── inventory/
│       ├── production/
│       └── staging/
│
├── deploy/                       # Kubernetes manifests
│   ├── helm/                    # Helm charts
│   │   ├── scylladb/
│   │   ├── redpanda/
│   │   ├── dragonflydb/
│   │   ├── clickhouse/
│   │   ├── minio/
│   │   ├── envoy/
│   │   └── seastar-services/
│   └── k8s/                     # Raw manifests
│       ├── namespaces/
│       ├── configmaps/
│       └── secrets/
│
├── scripts/
│   ├── deploy-full-stack.sh    # Master orchestration
│   ├── build-all.sh            # Build all services
│   ├── backup-restore.sh       # Backup/restore
│   └── migrate-infra.sh        # Migrate to new location
│
└── environments/
    ├── production.tfvars
    ├── staging.tfvars
    └── development.tfvars
```

## Deployment Modes

### Mode 1: Bare-Metal (Fastest)

```bash
# Best performance, full control
# Hetzner, OVH, your datacenter

export DEPLOY_MODE=bare-metal
export PROVIDER=hetzner  # or ovh, custom
make deploy-all ENV=production
```

### Mode 2: Cloud (AWS/GCP/Azure)

```bash
# Quick provisioning, managed infrastructure

export DEPLOY_MODE=cloud
export PROVIDER=aws  # or gcp, azure
make deploy-all ENV=production
```

### Mode 3: Hybrid (Edge + Cloud)

```bash
# Edge PoPs on bare-metal, control plane in cloud

export DEPLOY_MODE=hybrid
export EDGE_PROVIDER=hetzner
export CONTROL_PROVIDER=aws
make deploy-all ENV=production
```

## Step-by-Step Automation

### Step 1: Infrastructure Provisioning (Terraform)

Provisions servers, networks, firewalls, load balancers.

```bash
cd terraform

# Initialize
terraform init

# Plan (review what will be created)
terraform plan -var-file=../environments/production.tfvars

# Apply (create infrastructure)
terraform apply -var-file=../environments/production.tfvars

# Output: Inventory of servers with IPs
terraform output -json > ../ansible/inventory/production/terraform-inventory.json
```

**What gets created:**

- 3+ servers (64 cores, 256GB RAM, NVMe)
- Private network (10.0.0.0/8)
- Firewall rules
- Load balancer (optional)
- DNS records (optional)

### Step 2: OS Configuration (Ansible)

Configures kernel, installs packages, tunes performance.

```bash
cd ansible

# Bootstrap (Python, sudo, users)
ansible-playbook playbooks/01-bootstrap.yml -i inventory/production

# Kernel tuning (hugepages, sysctl, CPU governor)
ansible-playbook playbooks/02-kernel-tuning.yml -i inventory/production

# Install k3s cluster
ansible-playbook playbooks/03-k3s-install.yml -i inventory/production

# Install monitoring
ansible-playbook playbooks/04-monitoring.yml -i inventory/production
```

**What gets configured:**

- Kernel parameters (vm, net, fs)
- Hugepages (1024x 2MB pages)
- CPU governor (performance)
- IRQ affinity
- NIC tuning (RSS, offload)
- Docker, k3s, Helm
- Security hardening

### Step 3: Data Plane Deployment (Helm)

Deploys databases, caches, message queues.

```bash
cd deploy

# Deploy all data plane components
./scripts/deploy-dataplane.sh production

# Individual components
helm install scylla ./helm/scylladb -f values/production/scylla.yaml
helm install redpanda ./helm/redpanda -f values/production/redpanda.yaml
helm install dragonfly ./helm/dragonflydb -f values/production/dragonfly.yaml
helm install clickhouse ./helm/clickhouse -f values/production/clickhouse.yaml
helm install minio ./helm/minio -f values/production/minio.yaml
```

**What gets deployed:**

- ScyllaDB (3-node cluster, 96GB RAM each)
- Redpanda (3-node, 32GB RAM each)
- DragonflyDB (3-node, 64GB RAM each)
- ClickHouse (1-node, 128GB RAM)
- MinIO (3-node distributed)

### Step 4: Application Deployment

Deploys Seastar and Glommio services.

```bash
# Build all services
make build-all

# Deploy Seastar services (hostNetwork + CPU pinning)
helm install ad-server ./helm/seastar-services \
  --set service=ad-server \
  --set cpuSet="0-23" \
  --set memory=64Gi \
  -f values/production/ad-server.yaml

# Deploy Glommio services (standard k8s)
kubectl apply -f deploy/k8s/glommio-services/
```

### Step 5: Validation

```bash
# Run validation suite
./scripts/validate-deployment.sh production

# Load test
./scripts/load-test.sh production 10000  # 10k RPS
```

## Configuration Files

### Example: environments/production.tfvars

```hcl
# Provider (hetzner, ovh, aws, gcp, azure, custom)
provider = "hetzner"

# Region/Location
region = "fsn1"  # Hetzner Falkenstein

# Server specs
server_count = 5
server_type = "CCX63"  # 64 vCores, 256GB RAM, 1.5TB NVMe

# Network
private_network_cidr = "10.10.0.0/16"
enable_ipv6 = true

# Storage
additional_volumes = [
  {
    size = 2000  # 2TB
    type = "nvme"
  }
]

# Tags
tags = {
  project     = "adplatform"
  environment = "production"
  managed_by  = "terraform"
}
```

### Example: ansible/inventory/production/hosts.yml

```yaml
all:
  vars:
    ansible_user: deploy
    ansible_python_interpreter: /usr/bin/python3

  children:
    control_plane:
      hosts:
        node1:
          ansible_host: 10.10.0.10
          public_ip: 88.99.1.1

    data_plane:
      hosts:
        node2:
          ansible_host: 10.10.0.11
          public_ip: 88.99.1.2
        node3:
          ansible_host: 10.10.0.12
          public_ip: 88.99.1.3

    edge:
      hosts:
        node4:
          ansible_host: 10.10.0.13
          public_ip: 88.99.1.4
        node5:
          ansible_host: 10.10.0.14
          public_ip: 88.99.1.5
```

## Migration Between Providers

### Scenario: Moving from Hetzner to OVH

```bash
# 1. Backup data from old infrastructure
./scripts/backup-all.sh hetzner production

# 2. Provision new infrastructure on OVH
cd terraform
terraform apply -var-file=../environments/ovh-production.tfvars

# 3. Configure new servers
cd ../ansible
ansible-playbook playbooks/full-setup.yml -i inventory/ovh-production

# 4. Restore data to new infrastructure
./scripts/restore-all.sh ovh production

# 5. Update DNS (zero-downtime cutover)
./scripts/update-dns.sh ovh-production

# 6. Validate
./scripts/validate-deployment.sh ovh-production

# 7. Decommission old infrastructure
cd terraform
terraform destroy -var-file=../environments/hetzner-production.tfvars
```

## Disaster Recovery

### Backup Strategy

```bash
# Daily automated backups
0 2 * * * /opt/adplatform/scripts/backup-all.sh

# What gets backed up:
# - ScyllaDB snapshots (incremental)
# - ClickHouse data (compressed)
# - Configuration files
# - Secrets/certificates
# - Application state
```

### Restore Process

```bash
# Restore from backup (to new location)
./scripts/restore-all.sh <provider> <backup-date>

# Example: Restore production from 2024-01-15 backup
./scripts/restore-all.sh aws 2024-01-15

# Full stack operational in ~1 hour
```

## Multi-Region Deployment

```bash
# Deploy to multiple regions simultaneously
./scripts/deploy-multi-region.sh \
  --regions "us-east,eu-west,ap-south" \
  --mode active-active \
  --replication async

# Sets up:
# - ScyllaDB multi-DC replication
# - Redpanda cross-region mirroring
# - GeoDNS routing
# - Cross-region monitoring
```

## Cost Estimation

### Bare-Metal (Hetzner)

```
5x CCX63 servers: $500/month
3TB bandwidth: $50/month
Total: ~$550/month
```

### Cloud (AWS)

```
5x i4i.16xlarge: $8,000/month
Data transfer: $2,000/month
Total: ~$10,000/month
```

**Savings: ~$9,500/month (95%) with bare-metal!**

## Advanced Features

### GitOps Integration

```bash
# Setup ArgoCD for GitOps
ansible-playbook playbooks/setup-gitops.yml

# Now all changes via Git commits
git commit -m "Scale Redpanda to 5 nodes"
git push
# ArgoCD automatically applies changes
```

### Auto-Scaling

```bash
# Enable Kubernetes HPA
kubectl apply -f deploy/k8s/autoscaling/

# Scale based on metrics:
# - CPU > 70% → add pods
# - RPS > 1M → add nodes
# - Latency > 5ms → scale up
```

### Blue-Green Deployment

```bash
# Deploy to green environment
./scripts/deploy-blue-green.sh green production

# Test green
./scripts/validate-deployment.sh green

# Switch traffic (zero downtime)
./scripts/switch-traffic.sh green

# Rollback if needed
./scripts/switch-traffic.sh blue
```

## Monitoring During Migration

```bash
# Real-time migration dashboard
./scripts/migration-monitor.sh

# Shows:
# - Data sync progress
# - Traffic routing
# - Error rates
# - Latency comparison
# - Cost tracking
```

## Security Hardening

All automation includes:

- ✅ Firewall rules (only required ports)
- ✅ SSH key-only authentication
- ✅ Automatic security updates
- ✅ mTLS between services
- ✅ Secrets encryption (Vault)
- ✅ Network segmentation
- ✅ DDoS protection (XDP)

## Troubleshooting

### Common Issues

**Issue: Terraform fails to provision**

```bash
# Check provider credentials
terraform refresh

# Increase timeouts
export TF_CLI_TIMEOUT=3600

# Retry
terraform apply -auto-approve
```

**Issue: Ansible playbook hangs**

```bash
# Increase SSH timeout
export ANSIBLE_TIMEOUT=300

# Run with verbose
ansible-playbook -vvv playbooks/02-kernel-tuning.yml
```

**Issue: k3s cluster won't form**

```bash
# Check firewall
ansible all -m shell -a "ufw status"

# Check k3s logs
ansible all -m shell -a "journalctl -u k3s -n 100"

# Reset and retry
ansible-playbook playbooks/k3s-reset.yml
ansible-playbook playbooks/03-k3s-install.yml
```

## Next Steps

1. **Review** `environments/example.tfvars` and create your config
2. **Test** on staging environment first
3. **Run** `make deploy-all ENV=staging`
4. **Validate** deployment
5. **Deploy** to production when ready

## Support Scripts

All scripts support dry-run mode:

```bash
./scripts/deploy-full-stack.sh production --dry-run
```

See individual script help:

```bash
./scripts/deploy-full-stack.sh --help
```

---

**With this automation, you can deploy the entire AdPlatform stack to any infrastructure in ~30 minutes! 🚀**
