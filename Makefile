.PHONY: help deploy-all build-all clean validate

# Default environment
ENV ?= staging

help: ## Show this help message
	@echo 'Usage: make [target] ENV=[environment]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ''
	@echo 'Environments: production, staging, development'
	@echo ''
	@echo 'Examples:'
	@echo '  make deploy-all ENV=staging'
	@echo '  make build-all'
	@echo '  make validate ENV=production'

deploy-all: check-env ## Deploy complete infrastructure (Terraform + Ansible + K8s + Apps)
	@echo "🚀 Deploying full stack to $(ENV)..."
	@./scripts/deploy-full-stack.sh $(ENV)

deploy-infra: check-env ## Provision infrastructure only (Terraform)
	@echo "🏗️  Provisioning infrastructure for $(ENV)..."
	@cd terraform && terraform init && terraform apply -var-file=../environments/$(ENV).tfvars

deploy-config: check-env ## Configure servers only (Ansible)
	@echo "⚙️  Configuring servers for $(ENV)..."
	@cd ansible && ansible-playbook playbooks/01-bootstrap.yml -i inventory/$(ENV)
	@cd ansible && ansible-playbook playbooks/03-k3s-install.yml -i inventory/$(ENV)

deploy-apps: check-env ## Deploy applications only
	@echo "📦 Deploying applications for $(ENV)..."
	@SKIP_TERRAFORM=true SKIP_ANSIBLE=true SKIP_K8S=true SKIP_DATAPLANE=true \
		./scripts/deploy-full-stack.sh $(ENV)

# ============================================
# Platform Deployment (DevOps Platform)
# ============================================

configure-platform: ## Interactive configuration wizard
	@./scripts/configure-platform.sh

deploy-platform: check-env ## Deploy complete DevOps platform (GitLab, Monitoring, Data Engineering, ML)
	@echo "🏭 Deploying complete platform for $(ENV)..."
	@./scripts/deploy-platform.sh $(ENV)

deploy-base-platform: check-env ## Deploy base platform (GitLab + Monitoring)
	@echo "🔧 Deploying base platform (GitLab + Monitoring)..."
	@./scripts/deploy-platform.sh $(ENV) --only base

deploy-data-platform: check-env ## Deploy data engineering platform (Airflow + Spark + Jupyter)
	@echo "📊 Deploying data engineering platform..."
	@./scripts/deploy-platform.sh $(ENV) --only data-engineering

deploy-ml-platform: check-env ## Deploy ML platform (MLflow + Kubeflow)
	@echo "🤖 Deploying ML platform..."
	@./scripts/deploy-platform.sh $(ENV) --only ml

deploy-security-platform: check-env ## Deploy security platform (Vault + cert-manager)
	@echo "🔒 Deploying security platform..."
	@./scripts/deploy-platform.sh $(ENV) --only security

platform-info: check-env ## Show platform URLs and credentials
	@./scripts/platform-info.sh $(ENV)

platform-status: check-env ## Check platform health
	@./scripts/platform-status.sh $(ENV)

validate: check-env ## Validate deployment
	@echo "✅ Validating $(ENV) deployment..."
	@./scripts/validate-deployment.sh $(ENV)

# Note: platform-info.sh, platform-status.sh, load-test.sh, backup-all.sh, restore-all.sh
# are referenced but not yet implemented. Remove these targets when implementing those scripts.

destroy: check-env ## Destroy infrastructure (DANGEROUS!)
	@echo "⚠️  WARNING: This will destroy $(ENV) infrastructure!"
	@read -p "Type environment name to confirm: " confirm; \
	if [ "$$confirm" = "$(ENV)" ]; then \
		cd terraform && terraform destroy -var-file=../environments/$(ENV).tfvars; \
	else \
		echo "Confirmation failed. Aborting."; \
		exit 1; \
	fi

clean: ## Clean build artifacts
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf target/
	@rm -rf services/*/build/
	@rm -rf terraform/.terraform/
	@rm -rf terraform/*.tfstate*

logs: check-env ## Show logs from all services
	@echo "📜 Showing logs for $(ENV)..."
	@export KUBECONFIG=$$HOME/.kube/$(ENV)-config.yaml && kubectl logs -f -l app=adplatform --all-containers=true -n control

shell: check-env ## Open shell in a pod
	@export KUBECONFIG=$$HOME/.kube/$(ENV)-config.yaml && kubectl exec -it -n control deployment/campaign-mgmt -- /bin/bash

check-env:
	@if [ ! -f "environments/$(ENV).tfvars" ]; then \
		echo "❌ Environment file not found: environments/$(ENV).tfvars"; \
		echo "Create it from example: cp environments/production.tfvars.example environments/$(ENV).tfvars"; \
		exit 1; \
	fi

.DEFAULT_GOAL := help
