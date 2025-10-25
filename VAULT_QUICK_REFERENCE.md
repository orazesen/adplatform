# Vault Quick Reference

Quick commands for common Vault operations. Keep this handy!

## 🚀 Quick Start

```bash
# Complete setup (first time)
make setup-all

# Just deploy Vault
make setup-vault

# Just populate secrets
make populate-vault

# Access Vault UI
make vault-ui
# Then open: http://localhost:8200
```

## 🔐 Secret Operations

### Read Secrets

```bash
# Get secret (all fields as JSON)
make get-secret SECRET_PATH=adplatform/user-management

# Get specific field
make get-secret SECRET_PATH=adplatform/dragonfly FIELD=password

# List all secrets
kubectl exec -n adplatform vault-0 -- vault kv list secret/adplatform

# Read with kubectl
kubectl exec -n adplatform vault-0 -- \
  vault kv get secret/adplatform/user-management
```

### Update Secrets

```bash
# Update user-management secrets
kubectl exec -n adplatform vault-0 -- \
  vault kv put secret/adplatform/user-management \
  jwt_secret="new-secret" \
  secret_key="new-key"

# Update single field (preserves others)
kubectl exec -n adplatform vault-0 -- \
  vault kv patch secret/adplatform/user-management \
  jwt_secret="new-secret-only"

# Update Dragonfly password
kubectl exec -n adplatform vault-0 -- \
  vault kv patch secret/adplatform/dragonfly \
  password="new-redis-password"
```

### Create New Secrets

```bash
# Add new service secrets
kubectl exec -n adplatform vault-0 -- \
  vault kv put secret/adplatform/new-service \
  api_key="key123" \
  api_secret="secret456"
```

### Delete Secrets

```bash
# Delete secret (soft delete, can be recovered)
kubectl exec -n adplatform vault-0 -- \
  vault kv delete secret/adplatform/old-service

# Permanently destroy (unrecoverable)
kubectl exec -n adplatform vault-0 -- \
  vault kv destroy -versions=1 secret/adplatform/old-service
```

## 🔓 Vault State Management

### Check Status

```bash
# Check if Vault is sealed/unsealed
kubectl exec -n adplatform vault-0 -- vault status

# Check pod status
kubectl get pods -n adplatform -l app=vault
```

### Unseal Vault

```bash
# If Vault is sealed, unseal it
kubectl exec -n adplatform vault-0 -- \
  vault operator unseal <your-unseal-key>

# Check if unsealed
kubectl exec -n adplatform vault-0 -- vault status | grep Sealed
# Should show: Sealed false
```

### Seal Vault (emergency)

```bash
# Manually seal Vault (requires unseal to use again)
kubectl exec -n adplatform vault-0 -- vault operator seal
```

## 👤 Authentication & Tokens

### Login with Root Token

```bash
# Interactive login
kubectl exec -it -n adplatform vault-0 -- vault login

# Non-interactive (use with caution)
kubectl exec -n adplatform vault-0 -- \
  vault login <your-root-token>
```

### Test Kubernetes Auth

```bash
# From a pod with vault-auth ServiceAccount
kubectl run -it --rm vault-test \
  --image=hashicorp/vault:1.15 \
  --serviceaccount=vault-auth \
  --namespace=adplatform \
  -- sh

# Inside the pod:
export VAULT_ADDR=http://vault:8200
JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
vault write auth/kubernetes/login role=adplatform jwt=$JWT
```

### Create New Token

```bash
# Create token with adplatform-policy
kubectl exec -n adplatform vault-0 -- \
  vault token create -policy=adplatform-policy
```

## 📋 Policy & Role Management

### View Policy

```bash
# Read adplatform policy
kubectl exec -n adplatform vault-0 -- \
  vault policy read adplatform-policy
```

### View Role

```bash
# Read Kubernetes auth role
kubectl exec -n adplatform vault-0 -- \
  vault read auth/kubernetes/role/adplatform
```

### Update Policy

```bash
# Write new policy (from file)
cat <<EOF > /tmp/new-policy.hcl
path "secret/data/adplatform/*" {
  capabilities = ["read", "list"]
}
path "secret/data/adplatform/admin/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF

kubectl cp /tmp/new-policy.hcl adplatform/vault-0:/tmp/
kubectl exec -n adplatform vault-0 -- \
  vault policy write adplatform-policy /tmp/new-policy.hcl
```

## 🔄 Application Operations

### Restart Application After Secret Change

```bash
# user-management
kubectl rollout restart deployment/user-management -n adplatform

# Multiple services
kubectl rollout restart deployment/user-management -n adplatform
kubectl rollout restart deployment/varnish -n adplatform
kubectl rollout restart statefulset/dragonfly -n adplatform
```

### Check Application Logs

```bash
# View logs
kubectl logs -n adplatform -l app=user-management --tail=50

# Follow logs
kubectl logs -n adplatform -l app=user-management -f

# Check for Vault errors
kubectl logs -n adplatform -l app=user-management | grep -i vault
```

### Verify Secret Access

```bash
# For sidecar approach - check injected files
POD=$(kubectl get pods -n adplatform -l app=user-management -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n adplatform $POD -c user-management -- \
  cat /vault/secrets/jwt
```

## 📊 Monitoring & Debugging

### Check Vault Health

```bash
# Health endpoint
kubectl exec -n adplatform vault-0 -- \
  vault status

# Service health
kubectl get svc -n adplatform vault vault-ui

# Pod health
kubectl describe pod -n adplatform vault-0
```

### View Audit Logs (if enabled)

```bash
# Enable audit logging first
kubectl exec -n adplatform vault-0 -- \
  vault audit enable file file_path=/vault/audit/vault_audit.log

# View logs
kubectl exec -n adplatform vault-0 -- \
  cat /vault/audit/vault_audit.log | tail -20
```

### Debug Authentication Issues

```bash
# Check ServiceAccount exists
kubectl get sa vault-auth -n adplatform

# Check ServiceAccount token
kubectl describe sa vault-auth -n adplatform

# Check pod is using correct ServiceAccount
kubectl get pod <pod-name> -n adplatform -o yaml | grep serviceAccount

# Test from pod
kubectl exec -it <pod-name> -n adplatform -- sh
cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

## 💾 Backup & Recovery

### Backup Secrets

```bash
# Export all secrets to JSON
for path in dragonfly redpanda scylla user-management varnish envoy config; do
  kubectl exec -n adplatform vault-0 -- \
    vault kv get -format=json secret/adplatform/$path > backup-$path.json
done

# Create tarball
tar -czf vault-backup-$(date +%Y%m%d).tar.gz backup-*.json

# Clean up individual files
rm backup-*.json
```

### Restore Secrets

```bash
# Extract backup
tar -xzf vault-backup-20240115.tar.gz

# Restore each secret
for file in backup-*.json; do
  path=$(echo $file | sed 's/backup-//' | sed 's/.json//')
  kubectl exec -n adplatform vault-0 -- \
    vault kv put secret/adplatform/$path - < $file
done
```

### Backup Vault Data (PVC)

```bash
# Create snapshot of PVC
kubectl get pvc vault-pvc -n adplatform -o yaml > vault-pvc-backup.yaml

# Copy data from PVC (requires helper pod)
kubectl run -it --rm pvc-backup \
  --image=busybox \
  --namespace=adplatform \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "pvc-backup",
      "image": "busybox",
      "command": ["tar", "czf", "-", "/vault/data"],
      "volumeMounts": [{
        "name": "vault-data",
        "mountPath": "/vault/data"
      }]
    }],
    "volumes": [{
      "name": "vault-data",
      "persistentVolumeClaim": {"claimName": "vault-pvc"}
    }]
  }
}' > vault-data-backup-$(date +%Y%m%d).tar.gz
```

## 🔧 Maintenance

### Rotate Root Token

```bash
# Generate new root token (requires unseal key)
kubectl exec -n adplatform vault-0 -- \
  vault operator generate-root -init

# Follow prompts, then:
kubectl exec -n adplatform vault-0 -- \
  vault operator generate-root \
  -otp=<otp-from-init> \
  <unseal-key>

# Revoke old root token
kubectl exec -n adplatform vault-0 -- \
  vault token revoke <old-root-token>
```

### Rotate Secrets (Recommended Every 90 Days)

```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)

# Update in Vault
kubectl exec -n adplatform vault-0 -- \
  vault kv patch secret/adplatform/dragonfly \
  password="$NEW_PASSWORD"

# Update in application (depends on integration method)
# For sidecar: Restart pod
kubectl rollout restart deployment/dragonfly -n adplatform

# For direct API: Restart will pick up new secret
```

### Clean Old Secret Versions

```bash
# List versions
kubectl exec -n adplatform vault-0 -- \
  vault kv metadata get secret/adplatform/user-management

# Delete old versions (keep last 5)
kubectl exec -n adplatform vault-0 -- \
  vault kv metadata delete secret/adplatform/user-management \
  -versions=1,2,3
```

## 🆘 Emergency Procedures

### Vault Pod Crashed

```bash
# Check pod status
kubectl get pods -n adplatform -l app=vault

# View crash logs
kubectl logs -n adplatform vault-0 --previous

# Restart pod
kubectl delete pod vault-0 -n adplatform

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/vault-0 -n adplatform --timeout=120s

# Unseal if needed
kubectl exec -n adplatform vault-0 -- \
  vault operator unseal <your-unseal-key>
```

### Lost Unseal Key or Root Token

**If you lost the unseal key**: You cannot unseal Vault. You'll need to reinitialize (loses all data) or restore from backup.

**If you lost the root token**: You can generate a new root token using the unseal key:

```bash
kubectl exec -n adplatform vault-0 -- \
  vault operator generate-root -init

# Follow the prompts
```

### Application Can't Access Secrets

```bash
# 1. Check Vault is unsealed
kubectl exec -n adplatform vault-0 -- vault status

# 2. Check ServiceAccount exists
kubectl get sa vault-auth -n adplatform

# 3. Check role configuration
kubectl exec -n adplatform vault-0 -- \
  vault read auth/kubernetes/role/adplatform

# 4. Check policy
kubectl exec -n adplatform vault-0 -- \
  vault policy read adplatform-policy

# 5. Check application logs
kubectl logs -n adplatform -l app=user-management --tail=50
```

### Complete Reset (DANGER - Deletes All Secrets)

```bash
# Delete Vault deployment
kubectl delete -f k8s/vault-deployment.yaml

# Delete PVC (THIS DELETES ALL SECRETS)
kubectl delete pvc vault-pvc -n adplatform

# Delete RBAC
kubectl delete -f k8s/vault-rbac.yaml

# Redeploy
make setup-vault
make populate-vault
```

## 📱 Useful Aliases

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
# Vault aliases
alias vault-exec='kubectl exec -it -n adplatform vault-0 -- vault'
alias vault-logs='kubectl logs -n adplatform vault-0'
alias vault-status='kubectl exec -n adplatform vault-0 -- vault status'
alias vault-unseal='kubectl exec -n adplatform vault-0 -- vault operator unseal'

# Usage:
# vault-exec kv list secret/adplatform
# vault-status
# vault-unseal <your-key>
```

## 📚 Related Documentation

- **README_VAULT_MIGRATION.md** - Migration summary and next steps
- **VAULT_GUIDE.md** - Comprehensive Vault documentation
- **VAULT_INTEGRATION.md** - Application integration guide
- **VAULT_ARCHITECTURE.md** - Architecture diagrams and flows
- **VAULT_DEPLOYMENT_CHECKLIST.md** - Step-by-step deployment guide

## 🔗 External Resources

- Official Docs: https://developer.hashicorp.com/vault
- Kubernetes Auth: https://developer.hashicorp.com/vault/docs/auth/kubernetes
- KV v2 Secrets: https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2
- Best Practices: https://developer.hashicorp.com/vault/tutorials/operations

---

**Tip**: Bookmark this file! You'll use these commands frequently when managing Vault.
