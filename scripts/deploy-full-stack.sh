#!/usr/bin/env bash
# Master Infrastructure Deployment Script
# Deploys entire AdPlatform stack to any provider

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENV="${1:-staging}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_TERRAFORM="${SKIP_TERRAFORM:-false}"
SKIP_ANSIBLE="${SKIP_ANSIBLE:-false}"
SKIP_K8S="${SKIP_K8S:-false}"
SKIP_DATAPLANE="${SKIP_DATAPLANE:-false}"
SKIP_APPS="${SKIP_APPS:-false}"

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓${NC} $*"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠${NC} $*"
}

usage() {
    cat <<EOF
Usage: $0 [ENVIRONMENT] [OPTIONS]

Deploy entire AdPlatform infrastructure to any provider.

ENVIRONMENTS:
    production    Production environment
    staging       Staging environment  
    development   Development environment

OPTIONS:
    --dry-run              Show what would be done without doing it
    --skip-terraform       Skip infrastructure provisioning
    --skip-ansible         Skip OS configuration
    --skip-k8s             Skip Kubernetes setup
    --skip-dataplane       Skip data plane deployment
    --skip-apps            Skip application deployment
    --help                 Show this help message

EXAMPLES:
    # Full deployment to staging
    $0 staging

    # Production deployment (skip terraform if already provisioned)
    $0 production --skip-terraform

    # Dry run to see what would happen
    DRY_RUN=true $0 production

    # Update only applications
    $0 production --skip-terraform --skip-ansible --skip-k8s --skip-dataplane

EOF
    exit 1
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing=()
    
    command -v terraform >/dev/null 2>&1 || missing+=("terraform")
    command -v ansible >/dev/null 2>&1 || missing+=("ansible")
    command -v kubectl >/dev/null 2>&1 || missing+=("kubectl")
    command -v helm >/dev/null 2>&1 || missing+=("helm")
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        log "Install missing tools:"
        for tool in "${missing[@]}"; do
            case $tool in
                terraform)
                    echo "  brew install terraform  # or download from terraform.io"
                    ;;
                ansible)
                    echo "  pip3 install ansible"
                    ;;
                kubectl)
                    echo "  brew install kubectl"
                    ;;
                helm)
                    echo "  brew install helm"
                    ;;
            esac
        done
        exit 1
    fi
    
    log_success "All prerequisites installed"
}

validate_environment() {
    log "Validating environment configuration..."
    
    local tfvars_file="$PROJECT_ROOT/environments/${ENV}.tfvars"
    
    if [ ! -f "$tfvars_file" ]; then
        log_error "Environment file not found: $tfvars_file"
        log "Create it from example: cp environments/production.tfvars.example $tfvars_file"
        exit 1
    fi
    
    log_success "Environment configuration validated"
}

provision_infrastructure() {
    if [ "$SKIP_TERRAFORM" = "true" ]; then
        log_warn "Skipping infrastructure provisioning (SKIP_TERRAFORM=true)"
        return
    fi
    
    log "Provisioning infrastructure with Terraform..."
    
    cd "$PROJECT_ROOT/terraform"
    
    # Initialize
    log "Initializing Terraform..."
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would run: terraform init"
    else
        terraform init
    fi
    
    # Plan
    log "Planning infrastructure changes..."
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would run: terraform plan"
    else
        terraform plan -var-file="../environments/${ENV}.tfvars" -out=tfplan
    fi
    
    # Apply
    log "Applying infrastructure changes..."
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would run: terraform apply"
    else
        terraform apply tfplan
        
        # Generate Ansible inventory
        log "Generating Ansible inventory from Terraform output..."
        terraform output -json ansible_inventory > "$PROJECT_ROOT/ansible/inventory/${ENV}/terraform-inventory.json"
    fi
    
    log_success "Infrastructure provisioning complete"
}

configure_servers() {
    if [ "$SKIP_ANSIBLE" = "true" ]; then
        log_warn "Skipping server configuration (SKIP_ANSIBLE=true)"
        return
    fi
    
    log "Configuring servers with Ansible..."
    
    cd "$PROJECT_ROOT/ansible"
    
    local inventory="inventory/${ENV}"
    
    # Wait for servers to be SSH-accessible
    log "Waiting for servers to be accessible..."
    if [ "$DRY_RUN" = "false" ]; then
        sleep 30
    fi
    
    # Bootstrap
    log "Running bootstrap playbook..."
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would run: ansible-playbook playbooks/01-bootstrap.yml"
    else
        ansible-playbook playbooks/01-bootstrap.yml -i "$inventory" || {
            log_warn "Bootstrap failed, retrying in 30s..."
            sleep 30
            ansible-playbook playbooks/01-bootstrap.yml -i "$inventory"
        }
    fi
    
    # K3s installation
    if [ "$SKIP_K8S" = "false" ]; then
        log "Installing K3s cluster..."
        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY RUN] Would run: ansible-playbook playbooks/03-k3s-install.yml"
        else
            ansible-playbook playbooks/03-k3s-install.yml -i "$inventory"
            
            # Get kubeconfig
            log "Retrieving kubeconfig..."
            mkdir -p "$HOME/.kube"
            ansible control_plane -i "$inventory" -m fetch \
                -a "src=/etc/rancher/k3s/k3s.yaml dest=$HOME/.kube/${ENV}-config.yaml flat=yes"
                
            # Update server address
            sed -i.bak "s/127.0.0.1/$(terraform -chdir=$PROJECT_ROOT/terraform output -json control_plane_ips | jq -r '.[0]')/g" \
                "$HOME/.kube/${ENV}-config.yaml"
                
            export KUBECONFIG="$HOME/.kube/${ENV}-config.yaml"
            log_success "Kubeconfig saved to $HOME/.kube/${ENV}-config.yaml"
        fi
    fi
    
    log_success "Server configuration complete"
}

deploy_dataplane() {
    if [ "$SKIP_DATAPLANE" = "true" ]; then
        log_warn "Skipping data plane deployment (SKIP_DATAPLANE=true)"
        return
    fi
    
    log "Deploying data plane components..."
    
    export KUBECONFIG="$HOME/.kube/${ENV}-config.yaml"
    
    # Add Helm repos
    log "Adding Helm repositories..."
    if [ "$DRY_RUN" = "false" ]; then
        helm repo add scylla https://scylladb.github.io/charts
        helm repo add redpanda https://charts.redpanda.com
        helm repo add clickhouse https://clickhouse.github.io/helm-charts/
        helm repo add minio https://charts.min.io/
        helm repo update
    fi
    
    # ScyllaDB
    log "Deploying ScyllaDB..."
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would deploy ScyllaDB"
    else
        kubectl create namespace scylla --dry-run=client -o yaml | kubectl apply -f -
        helm upgrade --install scylla scylla/scylla \
            --namespace scylla \
            -f "$PROJECT_ROOT/deploy/helm/scylladb/values-${ENV}.yaml" \
            --wait --timeout 10m
    fi
    
    # Redpanda
    log "Deploying Redpanda..."
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would deploy Redpanda"
    else
        kubectl create namespace streaming --dry-run=client -o yaml | kubectl apply -f -
        helm upgrade --install redpanda redpanda/redpanda \
            --namespace streaming \
            -f "$PROJECT_ROOT/deploy/helm/redpanda/values-${ENV}.yaml" \
            --wait --timeout 10m
    fi
    
    # ClickHouse
    log "Deploying ClickHouse..."
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would deploy ClickHouse"
    else
        kubectl create namespace analytics --dry-run=client -o yaml | kubectl apply -f -
        helm upgrade --install clickhouse clickhouse/clickhouse \
            --namespace analytics \
            -f "$PROJECT_ROOT/deploy/helm/clickhouse/values-${ENV}.yaml" \
            --wait --timeout 10m
    fi
    
    # MinIO
    log "Deploying MinIO..."
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would deploy MinIO"
    else
        kubectl create namespace storage --dry-run=client -o yaml | kubectl apply -f -
        helm upgrade --install minio minio/minio \
            --namespace storage \
            -f "$PROJECT_ROOT/deploy/helm/minio/values-${ENV}.yaml" \
            --wait --timeout 10m
    fi
    
    # DragonflyDB
    log "Deploying DragonflyDB..."
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would deploy DragonflyDB"
    else
        kubectl create namespace cache --dry-run=client -o yaml | kubectl apply -f -
        kubectl apply -f "$PROJECT_ROOT/deploy/k8s/dragonflydb/" -n cache
    fi
    
    log_success "Data plane deployment complete"
}

deploy_applications() {
    if [ "$SKIP_APPS" = "true" ]; then
        log_warn "Skipping application deployment (SKIP_APPS=true)"
        return
    fi
    
    log "Deploying applications..."
    
    # Build applications first
    log "Building applications..."
    if [ "$DRY_RUN" = "false" ]; then
        "$SCRIPT_DIR/build-all.sh"
    fi
    
    # Deploy Glommio services
    log "Deploying Glommio services..."
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would deploy Glommio services"
    else
        kubectl create namespace control --dry-run=client -o yaml | kubectl apply -f -
        kubectl apply -f "$PROJECT_ROOT/deploy/k8s/glommio-services/" -n control
    fi
    
    # Deploy Seastar services (via Ansible - systemd on bare metal)
    log "Deploying Seastar services..."
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would deploy Seastar services"
    else
        cd "$PROJECT_ROOT/ansible"
        ansible-playbook playbooks/deploy-seastar-services.yml \
            -i "inventory/${ENV}" \
            -e "binary_path=$PROJECT_ROOT/target/seastar/release"
    fi
    
    log_success "Application deployment complete"
}

deploy_monitoring() {
    log "Deploying monitoring stack..."
    
    export KUBECONFIG="$HOME/.kube/${ENV}-config.yaml"
    
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would deploy monitoring stack"
        return
    fi
    
    # Prometheus + Grafana
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --wait --timeout 10m
        
    log_success "Monitoring deployment complete"
}

validate_deployment() {
    log "Validating deployment..."
    
    export KUBECONFIG="$HOME/.kube/${ENV}-config.yaml"
    
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would validate deployment"
        return
    fi
    
    # Check all pods
    log "Checking pod status..."
    kubectl get pods -A
    
    # Wait for pods to be ready
    log "Waiting for all pods to be ready..."
    kubectl wait --for=condition=ready pod --all -A --timeout=600s || log_warn "Some pods not ready"
    
    # Run validation script
    if [ -f "$SCRIPT_DIR/validate-deployment.sh" ]; then
        "$SCRIPT_DIR/validate-deployment.sh" "$ENV"
    fi
    
    log_success "Deployment validation complete"
}

print_summary() {
    log_success "Deployment complete! 🚀"
    echo ""
    echo "Environment: $ENV"
    echo "Kubeconfig: $HOME/.kube/${ENV}-config.yaml"
    echo ""
    echo "Next steps:"
    echo "  1. export KUBECONFIG=$HOME/.kube/${ENV}-config.yaml"
    echo "  2. kubectl get pods -A"
    echo "  3. kubectl get svc -A"
    echo ""
    echo "Access services:"
    echo "  • Grafana: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    echo "  • ScyllaDB: kubectl port-forward -n scylla svc/scylla 9042:9042"
    echo ""
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-terraform)
                SKIP_TERRAFORM=true
                shift
                ;;
            --skip-ansible)
                SKIP_ANSIBLE=true
                shift
                ;;
            --skip-k8s)
                SKIP_K8S=true
                shift
                ;;
            --skip-dataplane)
                SKIP_DATAPLANE=true
                shift
                ;;
            --skip-apps)
                SKIP_APPS=true
                shift
                ;;
            --help|-h)
                usage
                ;;
            *)
                ENV="$1"
                shift
                ;;
        esac
    done
    
    log "Starting AdPlatform deployment"
    log "Environment: $ENV"
    log "Dry run: $DRY_RUN"
    echo ""
    
    check_prerequisites
    validate_environment
    
    # Execute deployment steps
    provision_infrastructure
    configure_servers
    deploy_dataplane
    deploy_applications
    deploy_monitoring
    validate_deployment
    
    print_summary
}

# Handle Ctrl+C gracefully
trap 'log_error "Deployment interrupted"; exit 130' INT

main "$@"
