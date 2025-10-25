#!/bin/bash
set -e

echo "================================================"
echo "HashiCorp Vault Setup for Ad Platform"
echo "================================================"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Deploy Vault
echo "1. Deploying Vault to Kubernetes..."
kubectl apply -f k8s/vault-rbac.yaml
kubectl apply -f k8s/vault-deployment.yaml

echo "   Waiting for Vault pod to be ready..."
kubectl wait --for=condition=ready pod -l app=vault -n adplatform --timeout=300s

echo "   ✓ Vault deployed successfully"
echo ""

# Get Vault pod name
VAULT_POD=$(kubectl get pods -n adplatform -l app=vault -o jsonpath='{.items[0].metadata.name}')
echo "   Vault pod: $VAULT_POD"
echo ""

# Initialize Vault
echo "2. Initializing Vault..."
INIT_OUTPUT=$(kubectl exec -n adplatform $VAULT_POD -- vault operator init -key-shares=1 -key-threshold=1 -format=json)

# Extract keys and root token
UNSEAL_KEY=$(echo $INIT_OUTPUT | jq -r '.unseal_keys_b64[0]')
ROOT_TOKEN=$(echo $INIT_OUTPUT | jq -r '.root_token')

echo "   ✓ Vault initialized"
echo ""

# Save credentials to a secure file
VAULT_CREDS_FILE="vault-credentials.txt"
cat > $VAULT_CREDS_FILE <<EOF
================================================
VAULT CREDENTIALS - KEEP THIS FILE SECURE!
Generated: $(date)
================================================

Unseal Key: $UNSEAL_KEY
Root Token: $ROOT_TOKEN

IMPORTANT:
- Store these credentials in a secure password manager
- Delete this file after saving the credentials
- You'll need the unseal key every time Vault restarts
- The root token has full access to Vault

================================================
EOF

echo "   ⚠️  Credentials saved to: $VAULT_CREDS_FILE"
echo "   ⚠️  IMPORTANT: Save these credentials securely and delete the file!"
echo ""

# Unseal Vault
echo "3. Unsealing Vault..."
kubectl exec -n adplatform $VAULT_POD -- vault operator unseal $UNSEAL_KEY > /dev/null
echo "   ✓ Vault unsealed"
echo ""

# Login with root token
echo "4. Logging in to Vault..."
kubectl exec -n adplatform $VAULT_POD -- vault login $ROOT_TOKEN > /dev/null
echo "   ✓ Logged in successfully"
echo ""

# Enable KV secrets engine
echo "5. Enabling KV secrets engine..."
kubectl exec -n adplatform $VAULT_POD -- vault secrets enable -path=secret kv-v2 2>/dev/null || echo "   KV engine already enabled"
echo "   ✓ KV secrets engine enabled at path: secret/"
echo ""

# Enable Kubernetes auth
echo "6. Enabling Kubernetes authentication..."
kubectl exec -n adplatform $VAULT_POD -- vault auth enable kubernetes 2>/dev/null || echo "   Kubernetes auth already enabled"

# Get Kubernetes CA cert and token
echo "   Getting Kubernetes CA certificate..."
K8S_CA_CERT=$(kubectl exec -n adplatform $VAULT_POD -- cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)
K8S_TOKEN=$(kubectl exec -n adplatform $VAULT_POD -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# Configure Kubernetes auth
kubectl exec -n adplatform $VAULT_POD -- vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443" \
    kubernetes_ca_cert="$K8S_CA_CERT" \
    token_reviewer_jwt="$K8S_TOKEN" > /dev/null

echo "   ✓ Kubernetes authentication configured"
echo ""

# Create policy for applications
echo "7. Creating application policies..."
cat <<EOF | kubectl exec -i -n adplatform $VAULT_POD -- vault policy write adplatform-policy -
path "secret/data/adplatform/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/adplatform/*" {
  capabilities = ["list"]
}
EOF

echo "   ✓ Policy 'adplatform-policy' created"
echo ""

# Create Kubernetes auth role
echo "8. Creating Kubernetes auth role..."
kubectl exec -n adplatform $VAULT_POD -- vault write auth/kubernetes/role/adplatform \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=adplatform \
    policies=adplatform-policy \
    ttl=24h > /dev/null

echo "   ✓ Kubernetes role 'adplatform' created"
echo ""

# Create secret for Vault token in cluster
echo "9. Creating Kubernetes secret for Vault access..."
kubectl create secret generic vault-token \
    --from-literal=token=$ROOT_TOKEN \
    --from-literal=addr=http://vault:8200 \
    -n adplatform --dry-run=client -o yaml | kubectl apply -f -

echo "   ✓ Vault token secret created"
echo ""

echo "================================================"
echo "✅ Vault Setup Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Run './scripts/populate-vault-secrets.sh' to add secrets"
echo "  2. Access Vault UI at: http://localhost:8200"
echo "     (run: kubectl port-forward -n adplatform svc/vault-ui 8200:8200)"
echo "  3. Login with root token: $ROOT_TOKEN"
echo ""
echo "⚠️  IMPORTANT: Save the credentials from $VAULT_CREDS_FILE"
echo "⚠️  Then delete the file: rm $VAULT_CREDS_FILE"
echo ""
