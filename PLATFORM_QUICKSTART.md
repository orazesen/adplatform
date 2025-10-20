# 🚀 Platform Quickstart - 3 Steps to Full DevOps

## TL;DR - Get Running in 30 Minutes

```bash
# 1. Configure (5 minutes)
./scripts/configure-platform.sh

# 2. Deploy infrastructure (from INFRASTRUCTURE_AUTOMATION.md)
make deploy-infra ENV=production

# 3. Deploy platform (25 minutes)
make deploy-platform ENV=production

# ✅ Done! GitLab, Grafana, Airflow, JupyterHub, MLflow all ready!
```

---

## What You Get

After deployment, you'll have a **complete development platform**:

### ✅ Development Tools

- **GitLab** - Git repos, CI/CD, container registry
- **GitLab Runners** - Auto-scaling build agents
- **Container Registry** - Private Docker registry

### ✅ Monitoring & Observability

- **Grafana** - Metrics dashboards
- **Prometheus** - Metrics collection
- **Loki** - Log aggregation
- **Jaeger** - Distributed tracing
- **AlertManager** - Alert routing

### ✅ Data Engineering

- **Airflow** - Workflow orchestration
- **Spark** - Data processing
- **JupyterHub** - Multi-user notebooks

### ✅ ML Platform

- **MLflow** - Experiment tracking & model registry
- **Kubeflow** - ML pipelines
- **PostgreSQL** - Metadata storage

### ✅ Security

- **Vault** - Secrets management
- **Linkerd** - Service mesh with mTLS
- **cert-manager** - Automatic TLS certificates

---

## Step-by-Step Guide

### Step 1: Configure Platform

Run the interactive wizard:

```bash
cd /Users/orath/development/projects/server/rust/adplatform
./scripts/configure-platform.sh
```

The wizard will ask for:

- Your domain name (e.g., `example.com`)
- Admin email
- Passwords for:
  - GitLab admin
  - Grafana admin
  - Airflow admin
  - JupyterHub admin
  - Kubeflow admin
  - PostgreSQL
  - ClickHouse
  - MinIO

**Tip:** Use a password manager to generate strong passwords!

### Step 2: Deploy Infrastructure

First, deploy the base infrastructure (servers, network, K3s):

```bash
# Copy and configure Terraform vars
cp environments/production.tfvars.example environments/production.tfvars
vim environments/production.tfvars

# Deploy infrastructure
make deploy-infra ENV=production

# This creates:
# - 5 servers (1 control, 3 data, 1+ edge)
# - Private network
# - Firewall rules
# - K3s cluster with Cilium
```

**Time:** ~15 minutes

### Step 3: Deploy Platform

Now deploy all the DevOps tools:

```bash
make deploy-platform ENV=production
```

This will install (in order):

1. **Base Platform** (~10 min)

   - cert-manager (TLS)
   - Nginx Ingress
   - MinIO (object storage)
   - GitLab
   - Prometheus + Grafana
   - Loki (logging)
   - Jaeger (tracing)

2. **Data Engineering** (~8 min)

   - Apache Airflow
   - Apache Spark
   - JupyterHub

3. **ML Platform** (~5 min)

   - PostgreSQL
   - MLflow
   - Kubeflow Pipelines

4. **Security** (~2 min)
   - HashiCorp Vault
   - Linkerd service mesh

**Total Time:** ~25 minutes

### Step 4: Access Your Platform

Get all URLs and credentials:

```bash
make platform-info ENV=production
```

Output example:

```
🎉 Platform Ready!

GitLab:        https://gitlab.example.com
               User: root / Password: [from config]

Grafana:       https://grafana.example.com
               User: admin / Password: [from config]

Airflow:       https://airflow.example.com
               User: admin / Password: [from config]

JupyterHub:    https://jupyter.example.com
               User: admin / Password: [from config]

MLflow:        https://mlflow.example.com

Vault:         https://vault.example.com
               Token: [shown once]
```

### Step 5: Configure DNS

Point your domain to the load balancer IP:

```bash
# Get the IP
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Add DNS records (A or CNAME):
gitlab.example.com      -> <LOAD_BALANCER_IP>
grafana.example.com     -> <LOAD_BALANCER_IP>
airflow.example.com     -> <LOAD_BALANCER_IP>
jupyter.example.com     -> <LOAD_BALANCER_IP>
mlflow.example.com      -> <LOAD_BALANCER_IP>
vault.example.com       -> <LOAD_BALANCER_IP>
jaeger.example.com      -> <LOAD_BALANCER_IP>
prometheus.example.com  -> <LOAD_BALANCER_IP>
```

**Or use wildcard DNS:**

```
*.example.com -> <LOAD_BALANCER_IP>
```

### Step 6: Initialize Vault

Vault needs to be initialized once:

```bash
kubectl exec -n vault vault-0 -- vault operator init

# Save the unseal keys and root token!
# You'll need 3 of 5 unseal keys to unseal Vault
```

### Step 7: Setup GitLab CI/CD Templates

Create pre-configured CI/CD templates:

```bash
./scripts/setup-gitlab-templates.sh
```

This creates template projects with `.gitlab-ci.yml` files for:

- Rust projects
- Python projects
- Node.js projects
- Seastar projects
- ML training projects

---

## Your First Project

### 1. Login to GitLab

Open `https://gitlab.example.com`

- Username: `root`
- Password: [from platform-config.yaml]

### 2. Create New Project

- Click "New Project"
- Choose "Create from template"
- Select "Rust Microservice" template
- Name: `my-first-service`

### 3. Clone and Code

```bash
git clone https://gitlab.example.com/root/my-first-service.git
cd my-first-service

# Write code
vim src/main.rs

# Commit and push
git add .
git commit -m "Initial implementation"
git push
```

### 4. Watch Magic Happen! ✨

GitLab CI/CD automatically:

1. ✅ Runs tests
2. ✅ Builds Docker image
3. ✅ Pushes to registry
4. ✅ Deploys to staging
5. ✅ Shows metrics in Grafana
6. ✅ Streams logs to Loki
7. ✅ Traces requests in Jaeger

**No manual DevOps work!** 🎉

### 5. Monitor Your Service

Open Grafana: `https://grafana.example.com`

You'll see:

- Request rate, latency, errors
- CPU, memory, network usage
- Database query performance
- Cache hit rates

All **automatically configured**!

---

## Advanced: Deploy to Production

The pipeline has a manual approval for production:

1. Go to GitLab → CI/CD → Pipelines
2. Find your successful pipeline
3. Click "Deploy to Production" (manual action)
4. Approve

Your service is now live in production! 🚀

---

## Component-Specific Deployment

Deploy only specific parts:

```bash
# Just GitLab + Monitoring
make deploy-base-platform ENV=production

# Just Data Engineering
make deploy-data-platform ENV=production

# Just ML Platform
make deploy-ml-platform ENV=production

# Just Security
make deploy-security-platform ENV=production
```

---

## Check Platform Health

```bash
make platform-status ENV=production
```

Shows health of:

- All pods
- All services
- Ingress status
- TLS certificate status

---

## Troubleshooting

### Platform won't deploy

```bash
# Check prerequisites
kubectl version
helm version
terraform version
ansible --version

# Check cluster connectivity
kubectl get nodes
kubectl get pods --all-namespaces
```

### GitLab not accessible

```bash
# Check GitLab pods
kubectl get pods -n gitlab

# Check ingress
kubectl get ingress -n gitlab

# Check DNS
nslookup gitlab.example.com
```

### SSL certificate issues

```bash
# Check cert-manager
kubectl get pods -n cert-manager

# Check certificates
kubectl get certificate --all-namespaces

# Check ClusterIssuer
kubectl describe clusterissuer letsencrypt-prod
```

### Database connection errors

```bash
# Check PostgreSQL
kubectl get pods -n ml-platform -l app.kubernetes.io/name=postgresql

# Check ScyllaDB
kubectl get pods -l app=scylladb

# Check ClickHouse
kubectl get pods -l app=clickhouse
```

---

## Backup & Restore

### Manual Backup

```bash
make backup-platform ENV=production
```

Backs up:

- GitLab data (repos, registry)
- Grafana dashboards
- Vault secrets
- PostgreSQL databases

### Restore

```bash
make restore-platform ENV=production DATE=2024-01-15
```

---

## Scaling

### Add More GitLab Runners

```bash
make scale-gitlab-runners COUNT=10
```

### Add More Airflow Workers

```bash
make scale-airflow-workers COUNT=5
```

### Add More Jupyter Servers

```bash
make scale-jupyter COUNT=3
```

---

## Cost Optimization

### Hetzner (Bare-metal)

5 servers (CCX53):

- 64 cores, 256GB RAM each
- ~€400/month total
- **Best performance/cost**

### AWS (Cloud)

5 x r6i.16xlarge:

- 64 cores, 512GB RAM each
- ~$10,000/month
- **95% more expensive**

**Recommendation:** Start with Hetzner, migrate to cloud if needed (zero-downtime migration supported).

---

## What's Pre-installed

### Development Libraries (JupyterHub)

```python
# Data science
pandas, numpy, scipy
scikit-learn, xgboost, lightgbm
tensorflow, pytorch, jax
matplotlib, seaborn, plotly

# ML tracking
mlflow, wandb

# Distributed computing
dask, ray
```

### CI/CD Tools (GitLab Runners)

```bash
# Languages
rust, cargo, rustup
python, pip, virtualenv
node, npm, yarn
go, javac, maven

# Build tools
docker, docker-compose
kubectl, helm
terraform

# Code quality
clippy, rustfmt, black, eslint
```

---

## Summary

**What you provide:**

- Physical servers (or cloud VMs)
- Domain name
- Passwords

**What you get:**

- ✅ Complete CI/CD platform
- ✅ Full observability stack
- ✅ Data engineering tools
- ✅ ML platform
- ✅ Automatic deployments
- ✅ Pre-configured dashboards
- ✅ Auto-scaling
- ✅ TLS certificates
- ✅ Backup/restore

**Developer workflow:**

1. Push code to GitLab
2. Everything else is automatic!

**Time investment:**

- Setup: 30 minutes
- Per-project setup: 5 minutes (create repo, done!)

🎉 **You now have a platform that rivals Google, Netflix, Uber!** 🎉
