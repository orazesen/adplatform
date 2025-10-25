start: 
	@echo "================================================"
	@echo "Starting Ad Platform Deployment"
	@echo "================================================"
	@echo ""
	@echo "Step 1: Creating namespace..."
	kubectl apply -f k8s/namespace.yaml
	@echo ""
	@echo "Step 2: Building Docker images..."
	${MAKE} build-user-management-image
	@echo ""
	@echo "Step 3: Setting up Vault..."
	${MAKE} setup-vault
	@echo ""
	@echo "Step 4: Populating Vault secrets..."
	${MAKE} populate-vault
	@echo ""
	@echo "Step 5: Deploying services..."
	@sleep 5
	kubectl apply -f k8s/
	@echo ""
	@echo "================================================"
	@echo "✓ Deployment Complete!"
	@echo "================================================"
	@echo ""
	@echo "IMPORTANT: Save your Vault credentials!"
	@echo "1. Copy unseal key and root token from vault-credentials.txt"
	@echo "2. Store them in a secure password manager"
	@echo "3. Delete vault-credentials.txt: rm vault-credentials.txt"
	@echo ""
	@echo "Next steps:"
	@echo "  - Access Vault UI: make vault-ui"
	@echo "  - Check status: kubectl get pods -n adplatform"
	@echo "  - View logs: kubectl logs -n adplatform -l app=user-management"
	@echo ""

stop:
	kubectl delete namespace adplatform

# Setup Vault (run once)
setup-vault:
	@chmod +x scripts/*.sh
	@./scripts/setup-vault.sh

# Populate Vault with secrets
populate-vault:
	@./scripts/populate-vault-secrets.sh

build-user-management-image:
	docker build -t orazesen/user-management:latest -f user-management/Dockerfile user-management

# Get a secret from Vault
get-secret:
	@./scripts/get-vault-secret.sh $(SECRET_PATH) $(FIELD)

# Port forward to Vault UI
vault-ui:
	@echo "Opening Vault UI at http://localhost:8200"
	@echo "Press Ctrl+C to stop"
	@echo ""
	kubectl port-forward -n adplatform svc/vault-ui 8200:8200

# Show status of all pods
status:
	@echo "================================================"
	@echo "Ad Platform Status"
	@echo "================================================"
	@echo ""
	@echo "Namespace:"
	@kubectl get namespace adplatform 2>/dev/null || echo "  adplatform namespace not found"
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n adplatform 2>/dev/null || echo "  No pods found"
	@echo ""
	@echo "Services:"
	@kubectl get svc -n adplatform 2>/dev/null || echo "  No services found"
	@echo ""
	@echo "PersistentVolumeClaims:"
	@kubectl get pvc -n adplatform 2>/dev/null || echo "  No PVCs found"
	@echo ""

# Show logs from user-management
logs:
	@echo "Showing logs from user-management..."
	@echo "Press Ctrl+C to stop"
	@echo ""
	kubectl logs -n adplatform -l app=user-management -f