# 🏭 Complete Platform Automation - DevOps Platform as a Service

## Overview

This automation creates a **complete, production-ready development platform** on your infrastructure. You provide physical servers and credentials - we install everything else.

**What you get:**

- ✅ GitLab (CI/CD, container registry, package registry)
- ✅ Monitoring stack (Prometheus, Grafana, AlertManager)
- ✅ Logging stack (Loki, ELK, Promtail)
- ✅ Data Engineering (Airflow, Spark, Jupyter)
- ✅ ML Platform (MLflow, Kubeflow, JupyterHub)
- ✅ Secrets Management (HashiCorp Vault)
- ✅ Service Mesh (Linkerd2)
- ✅ Auto-deployment pipelines
- ✅ Development environments
- ✅ Pre-configured CI/CD templates

**Your workflow:**

1. Push physical servers → Everything installs automatically
2. Create new repo in GitLab → Push code → Auto-deploy!

---

## 🚀 One-Command Platform Setup

```bash
# 1. Configure credentials
cp platform-config.example.yaml platform-config.yaml
vim platform-config.yaml  # Set passwords, domains, emails

# 2. Deploy complete platform
make deploy-platform ENV=production

# 3. Wait ~45 minutes - get coffee ☕
# Platform ready! GitLab at https://gitlab.yourdomain.com
```

---

## 📋 What Gets Installed

### Development Platform

```yaml
GitLab CE/EE:
  - Git repositories
  - CI/CD pipelines
  - Container Registry
  - Package Registry (npm, pip, cargo)
  - Wiki & Documentation
  - Issue Tracking
  - Code Review
  - Auto DevOps

GitLab Runners:
  - Docker executor (for builds)
  - Kubernetes executor (for deployments)
  - Shell executor (for scripts)
  - Auto-scaling enabled
```

### Monitoring & Observability

```yaml
Prometheus Stack:
  - Prometheus (metrics)
  - Grafana (dashboards)
  - AlertManager (alerts)
  - Node Exporter (server metrics)
  - Blackbox Exporter (endpoint monitoring)

Logging:
  - Loki (log aggregation)
  - Promtail (log shipping)
  - Grafana (log visualization)
  - ElasticSearch (optional, for advanced search)
  - Kibana (optional, ELK stack)

Tracing:
  - Jaeger (distributed tracing)
  - Tempo (trace storage)
  - Grafana (trace visualization)

APM:
  - OpenTelemetry Collector
  - Service topology
  - Performance dashboards
```

### Data Engineering Platform

```yaml
Apache Airflow:
  - Workflow orchestration
  - DAG management
  - Web UI
  - Scheduler
  - Workers (auto-scaling)

Apache Spark:
  - Spark master
  - Spark workers
  - Jupyter integration
  - PySpark ready

Jupyter:
  - JupyterHub (multi-user)
  - JupyterLab
  - Pre-installed libraries
  - Shared notebooks

Data Storage:
  - MinIO (S3-compatible)
  - PostgreSQL (metadata)
  - ClickHouse (analytics)
```

### ML Platform

```yaml
MLflow:
  - Experiment tracking
  - Model registry
  - Model serving
  - Artifact storage

Kubeflow:
  - Jupyter notebooks
  - Katib (hyperparameter tuning)
  - KFServing (model serving)
  - Pipelines

Model Serving:
  - TensorFlow Serving
  - TorchServe
  - ONNX Runtime
  - Triton Inference Server
```

### Security & Secrets

```yaml
HashiCorp Vault:
  - Secrets management
  - Dynamic secrets
  - Encryption as a service
  - PKI/Certificate management

cert-manager:
  - Automatic TLS certificates
  - Let's Encrypt integration
  - Certificate renewal

OAuth2 Proxy:
  - Single Sign-On
  - GitLab OAuth integration
```

### Service Mesh & Networking

```yaml
Linkerd2:
  - Service-to-service mTLS
  - Traffic splitting
  - Retries & timeouts
  - Observability

Envoy:
  - API Gateway
  - Rate limiting
  - Load balancing

Ingress:
  - Nginx Ingress Controller
  - SSL termination
  - Path-based routing
```

---

## ⚙️ Configuration File

Create `platform-config.yaml`:

```yaml
# Platform Configuration
platform:
  domain: yourdomain.com # Your domain
  email: admin@yourdomain.com # Admin email (for Let's Encrypt)
  timezone: UTC

# GitLab Configuration
gitlab:
  admin:
    username: root
    password: CHANGE_ME_STRONG_PASSWORD # Will be prompted
    email: admin@yourdomain.com

  smtp: # Email configuration
    enabled: true
    address: smtp.gmail.com
    port: 587
    user: your-email@gmail.com
    password: CHANGE_ME # Will be prompted
    domain: yourdomain.com

  runners:
    registration_token: CHANGE_ME # Auto-generated if empty
    concurrent: 10

  registry:
    enabled: true
    storage: s3 # Uses MinIO

# Monitoring
monitoring:
  grafana:
    admin_password: CHANGE_ME # Will be prompted

  alertmanager:
    slack_webhook: https://hooks.slack.com/services/XXX # Optional
    pagerduty_key: CHANGE_ME # Optional
    email: alerts@yourdomain.com

# Data Engineering
airflow:
  admin:
    username: admin
    password: CHANGE_ME # Will be prompted
    email: airflow@yourdomain.com

  executor: kubernetes # or: celery, local

jupyterhub:
  admin:
    username: admin
    password: CHANGE_ME # Will be prompted

  users: # Pre-create users
    - data-scientist-1
    - data-engineer-1

# ML Platform
mlflow:
  tracking_uri: https://mlflow.yourdomain.com
  artifact_root: s3://mlflow-artifacts # MinIO

kubeflow:
  admin:
    email: admin@yourdomain.com
    password: CHANGE_ME # Will be prompted

# Secrets Management
vault:
  root_token: CHANGE_ME # Auto-generated if empty
  unseal_keys: 5
  unseal_threshold: 3

# Databases (already installed)
databases:
  scylladb:
    replication_factor: 3

  clickhouse:
    admin_password: CHANGE_ME # Will be prompted

  postgresql:
    admin_password: CHANGE_ME # Will be prompted

# Storage
minio:
  access_key: admin
  secret_key: CHANGE_ME # Will be prompted

  buckets: # Auto-create these buckets
    - gitlab-registry
    - gitlab-artifacts
    - gitlab-lfs
    - mlflow-artifacts
    - airflow-logs
    - backup

# TLS/SSL
ssl:
  provider: letsencrypt # or: self-signed, custom
  letsencrypt:
    email: admin@yourdomain.com
    staging: false # Set true for testing

# Backup
backup:
  enabled: true
  schedule: "0 2 * * *" # Daily at 2 AM
  retention_days: 30
  s3_bucket: backup
```

---

## 🎯 Deployment Process

### Step 1: Prepare Configuration

```bash
# Interactive configuration wizard
./scripts/configure-platform.sh

# This will prompt for:
# - GitLab admin password
# - Grafana admin password
# - Database passwords
# - SMTP credentials
# - Domain names
# - SSL certificates
```

### Step 2: Deploy Platform

```bash
# Full platform deployment
make deploy-platform ENV=production

# Or step-by-step:
make deploy-base-platform ENV=production        # GitLab, monitoring
make deploy-data-platform ENV=production        # Airflow, Spark, Jupyter
make deploy-ml-platform ENV=production          # MLflow, Kubeflow
make deploy-security-platform ENV=production    # Vault, cert-manager
```

### Step 3: Access Your Platform

```bash
# Get all URLs and credentials
make platform-info ENV=production
```

Output:

```
🎉 Platform Ready!

GitLab:        https://gitlab.yourdomain.com
               User: root / Password: [from config]

Grafana:       https://grafana.yourdomain.com
               User: admin / Password: [from config]

Airflow:       https://airflow.yourdomain.com
               User: admin / Password: [from config]

JupyterHub:    https://jupyter.yourdomain.com
               User: admin / Password: [from config]

MLflow:        https://mlflow.yourdomain.com

Vault:         https://vault.yourdomain.com
               Token: [shown once]

Prometheus:    https://prometheus.yourdomain.com
Jaeger:        https://jaeger.yourdomain.com
```

---

## 🔄 Development Workflow

### For Developers

1. **Create New Project**

   - Go to GitLab → New Project
   - Choose template (Rust, Python, Node.js, etc.)
   - Project created with pre-configured CI/CD

2. **Push Code**

   ```bash
   git clone https://gitlab.yourdomain.com/your-project.git
   cd your-project
   # Write code
   git add .
   git commit -m "Initial commit"
   git push
   ```

3. **Automatic Pipeline Runs**

   - ✅ Lint & format
   - ✅ Run tests
   - ✅ Build Docker image
   - ✅ Push to registry
   - ✅ Deploy to staging (auto)
   - ✅ Deploy to production (manual approval)

4. **Monitor in Grafana**
   - See metrics automatically
   - Pre-configured dashboards
   - Alerts configured

### Pre-configured CI/CD Templates

The platform includes ready-to-use `.gitlab-ci.yml` templates:

**Rust/Seastar Project:**

```yaml
# Auto-included from GitLab templates
include:
  - template: Rust.gitlab-ci.yml
  - template: Seastar.gitlab-ci.yml

stages:
  - test
  - build
  - deploy

test:
  stage: test
  script:
    - cargo test --all

build:
  stage: build
  script:
    - cargo build --release
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

deploy_staging:
  stage: deploy
  script:
    - kubectl set image deployment/my-app app=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA -n staging
  environment:
    name: staging
    url: https://staging.yourdomain.com
  only:
    - develop

deploy_production:
  stage: deploy
  script:
    - kubectl set image deployment/my-app app=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA -n production
  environment:
    name: production
    url: https://yourdomain.com
  when: manual
  only:
    - main
```

**Python/ML Project:**

```yaml
include:
  - template: Python.gitlab-ci.yml
  - template: MLflow.gitlab-ci.yml

stages:
  - test
  - train
  - deploy

test:
  stage: test
  script:
    - pip install -r requirements.txt
    - pytest tests/

train:
  stage: train
  script:
    - python train.py
    - mlflow models register ...
  artifacts:
    paths:
      - models/

deploy_model:
  stage: deploy
  script:
    - mlflow models serve ...
  environment:
    name: production
```

---

## 📊 Pre-configured Dashboards

### Grafana Dashboards (Auto-imported)

1. **Application Performance**

   - RPS, latency, error rate
   - Per-service breakdown
   - Database queries
   - Cache hit rates

2. **Infrastructure**

   - CPU, memory, disk, network
   - Kubernetes cluster health
   - Node resource usage

3. **GitLab CI/CD**

   - Pipeline success rate
   - Build duration
   - Runner utilization

4. **Data Engineering**

   - Airflow DAG runs
   - Spark job metrics
   - Data pipeline health

5. **ML Platform**
   - Model training metrics
   - Inference latency
   - Model accuracy trends

---

## 🔒 Security Features

All pre-configured:

- ✅ **mTLS** between all services (Linkerd)
- ✅ **Secrets** managed by Vault
- ✅ **SSO** via GitLab OAuth
- ✅ **Network policies** (Cilium)
- ✅ **RBAC** for Kubernetes
- ✅ **Automatic TLS** certificates (cert-manager)
- ✅ **Container scanning** (GitLab)
- ✅ **Dependency scanning** (GitLab)
- ✅ **SAST** (Static Application Security Testing)
- ✅ **DAST** (Dynamic Application Security Testing)

---

## 🎓 Pre-installed Development Environments

### Data Science Environment

Pre-installed in JupyterHub:

```python
# Python libraries
- pandas, numpy, scipy
- scikit-learn, xgboost, lightgbm
- tensorflow, pytorch, jax
- matplotlib, seaborn, plotly
- jupyter, jupyterlab
- mlflow, wandb
- dask, ray
```

### Data Engineering Environment

Pre-installed in Airflow:

```python
# Data engineering tools
- apache-airflow
- apache-spark (pyspark)
- dbt-core
- great-expectations
- sqlalchemy, psycopg2
- clickhouse-driver
- kafka-python
- prefect
```

### Rust Development

Pre-configured GitLab runner with:

```bash
# Rust toolchain
- rustup, cargo
- clippy, rustfmt
- cargo-audit, cargo-deny
- cross (cross-compilation)
- Seastar build tools
```

---

## 📦 Example: Create New Microservice

```bash
# 1. Create repo in GitLab UI (or via CLI)
gitlab project create \
  --name my-rust-service \
  --template rust-microservice

# 2. Clone and write code
git clone https://gitlab.yourdomain.com/your-project/my-rust-service.git
cd my-rust-service

# Project structure already created:
# - src/main.rs (hello world)
# - Dockerfile
# - .gitlab-ci.yml (pre-configured)
# - k8s/ (deployment manifests)

# 3. Write your code
vim src/main.rs

# 4. Push
git add .
git commit -m "Implement feature"
git push

# 5. Automatic pipeline runs:
# ✅ Build → Test → Docker → Deploy to staging
# ✅ Metrics appear in Grafana automatically
# ✅ Logs streamed to Loki
# ✅ Traces sent to Jaeger
```

**You're done! Service is live and monitored!**

---

## 🔧 Customization

### Add Custom CI/CD Template

```bash
# 1. Create template
cat > custom-template.yml << 'EOF'
.rust-performance-test:
  stage: test
  script:
    - cargo build --release
    - wrk2 -t8 -c200 -d30s http://localhost:8080
EOF

# 2. Upload to GitLab
gitlab project-file create \
  --project-id gitlab-templates \
  --file custom-template.yml \
  --file-path templates/Rust-Performance.gitlab-ci.yml

# 3. Use in projects
include:
  - template: Rust-Performance.gitlab-ci.yml
```

### Add Custom Grafana Dashboard

```bash
# Dashboard JSON in deploy/grafana/dashboards/
make platform-reload-dashboards
```

---

## 💾 Backup & Disaster Recovery

Automatic backups configured:

```yaml
Daily backups (2 AM):
  - GitLab (repos, DB, registry)
  - Monitoring data (Prometheus, Loki)
  - Vault secrets
  - Database snapshots
  - ML models & experiments

Stored in:
  - MinIO bucket: backup/
  - Retention: 30 days
  - Encrypted: Yes
```

Restore:

```bash
# Restore from backup
make platform-restore ENV=production DATE=2024-01-15
```

---

## 🚀 Performance Optimizations

Pre-configured:

- ✅ **Build caching** (GitLab Runner cache)
- ✅ **Docker layer caching**
- ✅ **Artifact caching**
- ✅ **Kubernetes resource limits**
- ✅ **Auto-scaling** (HPA for all services)
- ✅ **CDN** for static assets
- ✅ **Database connection pooling**

---

## 📈 Scaling the Platform

```bash
# Add more GitLab runners
make scale-gitlab-runners COUNT=10

# Add more Airflow workers
make scale-airflow-workers COUNT=5

# Add more Jupyter servers
make scale-jupyter COUNT=3
```

---

## 🎯 What You Need to Provide

**Minimal requirements:**

1. **Physical servers** (or cloud VMs)

   - Recommended: 5+ servers, 64 cores, 256GB RAM each

2. **Domain name**

   - Example: `yourdomain.com`
   - DNS configured to point to your servers

3. **Credentials** (prompted during setup)
   - GitLab admin password
   - Database passwords
   - SMTP credentials (for emails)
   - Slack webhook (optional)

**That's it! Everything else is automatic.**

---

## 🎉 Summary

After running `make deploy-platform`:

✅ GitLab with CI/CD ready
✅ Container registry ready
✅ Monitoring dashboards ready
✅ Logging aggregation ready
✅ Data engineering platform ready
✅ ML platform ready
✅ Secrets management ready
✅ Auto-deployment pipelines ready
✅ Development environments ready

**Your developers can:**

1. Create new repo in GitLab
2. Push code
3. Get automatic CI/CD, monitoring, and deployment!

**No manual DevOps work needed!** 🚀
