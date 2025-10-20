#!/usr/bin/env bash
set -euo pipefail

# Platform Deployment Script - Deploys Complete DevOps Platform
# Usage: ./deploy-platform.sh <environment> [--only <component>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
ENV="${1:-staging}"
DEPLOY_MODE="${2:-}"
COMPONENT="${3:-}"

CONFIG_FILE="$PROJECT_ROOT/platform-config.yaml"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}❌ Error: platform-config.yaml not found!${NC}"
    echo -e "${YELLOW}Run: make configure-platform${NC}"
    exit 1
fi

# Load configuration
DOMAIN=$(yq eval '.platform.domain' "$CONFIG_FILE")
ADMIN_EMAIL=$(yq eval '.platform.email' "$CONFIG_FILE")

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}║         Complete Platform Deployment                       ║${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Environment:${NC}  $ENV"
echo -e "${CYAN}Domain:${NC}       $DOMAIN"
echo -e "${CYAN}Admin Email:${NC}  $ADMIN_EMAIL"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
for cmd in kubectl helm terraform ansible yq; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}❌ $cmd is required but not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} $cmd"
done

# Deploy functions
deploy_namespace() {
    local ns=$1
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
}

deploy_base_platform() {
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Phase 1: Base Platform (GitLab + Monitoring)${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    # Namespaces
    deploy_namespace gitlab
    deploy_namespace monitoring
    deploy_namespace cert-manager
    
    # cert-manager (TLS certificates)
    echo -e "${CYAN}Installing cert-manager...${NC}"
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --set installCRDs=true \
        --wait
    
    # Create Let's Encrypt ClusterIssuer
    cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $ADMIN_EMAIL
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
    
    # Nginx Ingress Controller
    echo -e "${CYAN}Installing Nginx Ingress...${NC}"
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.metrics.enabled=true \
        --set controller.podAnnotations."prometheus\.io/scrape"=true \
        --wait
    
    # MinIO (Object Storage)
    echo -e "${CYAN}Installing MinIO...${NC}"
    MINIO_ACCESS_KEY=$(yq eval '.minio.access_key' "$CONFIG_FILE")
    MINIO_SECRET_KEY=$(yq eval '.minio.secret_key' "$CONFIG_FILE")
    
    helm repo add minio https://charts.min.io/
    helm upgrade --install minio minio/minio \
        --namespace minio \
        --create-namespace \
        --set rootUser=$MINIO_ACCESS_KEY \
        --set rootPassword=$MINIO_SECRET_KEY \
        --set replicas=3 \
        --set persistence.size=500Gi \
        --set ingress.enabled=true \
        --set ingress.hosts[0]="minio.$DOMAIN" \
        --wait
    
    # GitLab
    echo -e "${CYAN}Installing GitLab...${NC}"
    GITLAB_ROOT_PASSWORD=$(yq eval '.gitlab.admin.password' "$CONFIG_FILE")
    
    helm repo add gitlab https://charts.gitlab.io/
    helm upgrade --install gitlab gitlab/gitlab \
        --namespace gitlab \
        --set global.hosts.domain=$DOMAIN \
        --set global.hosts.externalIP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}') \
        --set global.edition=ce \
        --set global.initialRootPassword.secret=gitlab-root-password \
        --set certmanager.install=false \
        --set global.ingress.configureCertmanager=false \
        --set global.minio.enabled=false \
        --set global.registry.bucket=gitlab-registry \
        --set global.appConfig.lfs.bucket=gitlab-lfs \
        --set global.appConfig.artifacts.bucket=gitlab-artifacts \
        --set global.appConfig.backups.bucket=gitlab-backup \
        --set gitlab-runner.install=true \
        --set gitlab-runner.runners.privileged=true \
        --timeout 30m \
        --wait
    
    # Create root password secret
    kubectl create secret generic gitlab-root-password \
        --namespace gitlab \
        --from-literal=password=$GITLAB_ROOT_PASSWORD \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Prometheus + Grafana
    echo -e "${CYAN}Installing Prometheus Stack...${NC}"
    GRAFANA_PASSWORD=$(yq eval '.monitoring.grafana.admin_password' "$CONFIG_FILE")
    
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set grafana.adminPassword=$GRAFANA_PASSWORD \
        --set grafana.ingress.enabled=true \
        --set grafana.ingress.hosts[0]="grafana.$DOMAIN" \
        --set grafana.ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
        --set prometheus.ingress.enabled=true \
        --set prometheus.ingress.hosts[0]="prometheus.$DOMAIN" \
        --wait
    
    # Loki (Logging)
    echo -e "${CYAN}Installing Loki Stack...${NC}"
    helm repo add grafana https://grafana.github.io/helm-charts
    helm upgrade --install loki grafana/loki-stack \
        --namespace monitoring \
        --set loki.persistence.enabled=true \
        --set loki.persistence.size=100Gi \
        --set promtail.enabled=true \
        --wait
    
    # Jaeger (Tracing)
    echo -e "${CYAN}Installing Jaeger...${NC}"
    helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
    helm upgrade --install jaeger jaegertracing/jaeger \
        --namespace monitoring \
        --set provisionDataStore.cassandra=false \
        --set storage.type=memory \
        --set ingress.enabled=true \
        --set ingress.hosts[0]="jaeger.$DOMAIN" \
        --wait
    
    echo -e "${GREEN}✅ Base platform deployed!${NC}"
}

deploy_data_engineering() {
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Phase 2: Data Engineering Platform${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    deploy_namespace data-engineering
    
    # Apache Airflow
    echo -e "${CYAN}Installing Apache Airflow...${NC}"
    AIRFLOW_PASSWORD=$(yq eval '.airflow.admin.password' "$CONFIG_FILE")
    
    helm repo add apache-airflow https://airflow.apache.org
    helm upgrade --install airflow apache-airflow/airflow \
        --namespace data-engineering \
        --set executor=KubernetesExecutor \
        --set webserver.defaultUser.password=$AIRFLOW_PASSWORD \
        --set ingress.web.enabled=true \
        --set ingress.web.host="airflow.$DOMAIN" \
        --set ingress.web.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
        --timeout 20m \
        --wait
    
    # Apache Spark
    echo -e "${CYAN}Installing Apache Spark...${NC}"
    helm repo add spark-operator https://googlecloudplatform.github.io/spark-on-k8s-operator
    helm upgrade --install spark-operator spark-operator/spark-operator \
        --namespace data-engineering \
        --create-namespace \
        --set sparkJobNamespace=data-engineering \
        --wait
    
    # JupyterHub
    echo -e "${CYAN}Installing JupyterHub...${NC}"
    JUPYTER_PASSWORD=$(yq eval '.jupyterhub.admin.password' "$CONFIG_FILE")
    
    helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
    helm upgrade --install jupyterhub jupyterhub/jupyterhub \
        --namespace data-engineering \
        --set proxy.secretToken=$(openssl rand -hex 32) \
        --set hub.config.JupyterHub.admin_access=true \
        --set hub.config.Authenticator.admin_users[0]=admin \
        --set hub.config.DummyAuthenticator.password=$JUPYTER_PASSWORD \
        --set ingress.enabled=true \
        --set ingress.hosts[0]="jupyter.$DOMAIN" \
        --timeout 20m \
        --wait
    
    echo -e "${GREEN}✅ Data engineering platform deployed!${NC}"
}

deploy_ml_platform() {
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Phase 3: ML Platform${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    deploy_namespace ml-platform
    
    # PostgreSQL for MLflow
    echo -e "${CYAN}Installing PostgreSQL...${NC}"
    PG_PASSWORD=$(yq eval '.databases.postgresql.admin_password' "$CONFIG_FILE")
    
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm upgrade --install postgresql bitnami/postgresql \
        --namespace ml-platform \
        --set auth.postgresPassword=$PG_PASSWORD \
        --set primary.persistence.size=50Gi \
        --wait
    
    # MLflow
    echo -e "${CYAN}Installing MLflow...${NC}"
    helm repo add community-charts https://community-charts.github.io/helm-charts
    helm upgrade --install mlflow community-charts/mlflow \
        --namespace ml-platform \
        --set backendStore.postgres.enabled=true \
        --set backendStore.postgres.host=postgresql \
        --set backendStore.postgres.password=$PG_PASSWORD \
        --set artifactRoot.s3.enabled=true \
        --set artifactRoot.s3.bucket=mlflow-artifacts \
        --set ingress.enabled=true \
        --set ingress.hosts[0].host="mlflow.$DOMAIN" \
        --wait
    
    # Kubeflow (simplified - Pipelines only)
    echo -e "${CYAN}Installing Kubeflow Pipelines...${NC}"
    kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/cluster-scoped-resources?ref=2.0.0"
    kubectl wait --for condition=established --timeout=60s crd/applications.app.k8s.io
    kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/env/platform-agnostic?ref=2.0.0"
    
    echo -e "${GREEN}✅ ML platform deployed!${NC}"
}

deploy_security() {
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Phase 4: Security Platform${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    deploy_namespace vault
    
    # HashiCorp Vault
    echo -e "${CYAN}Installing HashiCorp Vault...${NC}"
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm upgrade --install vault hashicorp/vault \
        --namespace vault \
        --set server.ha.enabled=true \
        --set server.ha.replicas=3 \
        --set ui.enabled=true \
        --set ingress.enabled=true \
        --set ingress.hosts[0].host="vault.$DOMAIN" \
        --wait
    
    # Initialize Vault (if not already done)
    echo -e "${YELLOW}⚠️  Initialize Vault manually:${NC}"
    echo -e "  kubectl exec -n vault vault-0 -- vault operator init"
    
    # Service Mesh - Linkerd
    echo -e "${CYAN}Installing Linkerd...${NC}"
    curl -sL https://run.linkerd.io/install | sh
    export PATH=$PATH:$HOME/.linkerd2/bin
    linkerd check --pre
    linkerd install --crds | kubectl apply -f -
    linkerd install | kubectl apply -f -
    linkerd check
    
    # Linkerd Viz (Dashboard)
    linkerd viz install | kubectl apply -f -
    
    echo -e "${GREEN}✅ Security platform deployed!${NC}"
}

create_ci_templates() {
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Phase 5: CI/CD Templates${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    # Wait for GitLab to be ready
    echo -e "${CYAN}Waiting for GitLab...${NC}"
    kubectl wait --for=condition=ready pod -l app=webservice -n gitlab --timeout=600s
    
    # Create CI/CD templates project in GitLab
    # This will be done via GitLab API after deployment
    echo -e "${YELLOW}CI/CD templates will be created via GitLab API${NC}"
    echo -e "Run: ${GREEN}./scripts/setup-gitlab-templates.sh${NC}"
}

# Main deployment logic
if [[ "$DEPLOY_MODE" == "--only" ]]; then
    case $COMPONENT in
        base)
            deploy_base_platform
            ;;
        data-engineering)
            deploy_data_engineering
            ;;
        ml)
            deploy_ml_platform
            ;;
        security)
            deploy_security
            ;;
        *)
            echo -e "${RED}Unknown component: $COMPONENT${NC}"
            exit 1
            ;;
    esac
else
    # Full platform deployment
    deploy_base_platform
    deploy_data_engineering
    deploy_ml_platform
    deploy_security
    create_ci_templates
    
    echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║         🎉 Platform Deployment Complete!                   ║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}Platform URLs:${NC}"
    echo -e "  GitLab:        ${GREEN}https://gitlab.$DOMAIN${NC}"
    echo -e "  Grafana:       ${GREEN}https://grafana.$DOMAIN${NC}"
    echo -e "  Prometheus:    ${GREEN}https://prometheus.$DOMAIN${NC}"
    echo -e "  Airflow:       ${GREEN}https://airflow.$DOMAIN${NC}"
    echo -e "  JupyterHub:    ${GREEN}https://jupyter.$DOMAIN${NC}"
    echo -e "  MLflow:        ${GREEN}https://mlflow.$DOMAIN${NC}"
    echo -e "  Vault:         ${GREEN}https://vault.$DOMAIN${NC}"
    echo -e "  Jaeger:        ${GREEN}https://jaeger.$DOMAIN${NC}"
    echo ""
    echo -e "${CYAN}Get credentials:${NC}"
    echo -e "  ${GREEN}make platform-info ENV=$ENV${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Important next steps:${NC}"
    echo -e "  1. Initialize Vault: ${GREEN}kubectl exec -n vault vault-0 -- vault operator init${NC}"
    echo -e "  2. Setup GitLab templates: ${GREEN}./scripts/setup-gitlab-templates.sh${NC}"
    echo -e "  3. Configure DNS to point to: $(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
fi
