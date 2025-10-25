# Vault Deployment Checklist

Use this checklist to ensure a smooth deployment of HashiCorp Vault to your Kubernetes cluster.

## Pre-Deployment Checks

### ✅ Prerequisites

- [ ] Kubernetes cluster is running (verify: `kubectl cluster-info`)
- [ ] Namespace `adplatform` exists (verify: `kubectl get namespace adplatform`)
- [ ] You have cluster-admin permissions (needed for ClusterRoleBindings)
- [ ] `kubectl` is configured correctly (verify: `kubectl get nodes`)
- [ ] Sufficient storage for PersistentVolume (1Gi minimum)
- [ ] Scripts have executable permissions (will be handled by Makefile)

### ✅ Review Configuration

- [ ] Read `README_VAULT_MIGRATION.md` for overview
- [ ] Review `VAULT_GUIDE.md` for detailed documentation
- [ ] Review `VAULT_INTEGRATION.md` for application integration steps
- [ ] Review `VAULT_ARCHITECTURE.md` to understand the architecture
- [ ] Understand secrets structure in `secret/adplatform/*`

---

## Deployment Steps

### Step 1: Deploy Vault Infrastructure

```bash
make setup-vault
```

**What this does**:

- [x] Applies `k8s/vault-rbac.yaml` (ServiceAccounts, ClusterRoles, Bindings)
- [x] Applies `k8s/vault-deployment.yaml` (ConfigMap, PVC, Deployment, Services)
- [x] Waits for Vault pod to be ready
- [x] Initializes Vault with 1 unseal key and 1 root token
- [x] Unseals Vault automatically
- [x] Enables KV-v2 secrets engine at `secret/`
- [x] Configures Kubernetes authentication
- [x] Creates `adplatform-policy` for read access
- [x] Creates `adplatform` role bound to `vault-auth` ServiceAccount
- [x] Saves credentials to `vault-credentials.txt`

**Verify**:

```bash
# Check Vault pod is running
kubectl get pods -n adplatform -l app=vault
# Expected: vault-0  1/1  Running

# Check Vault status
kubectl exec -n adplatform vault-0 -- vault status
# Expected: Sealed: false

# Check services
kubectl get svc -n adplatform vault vault-ui
# Expected: vault (ClusterIP), vault-ui (LoadBalancer)
```

**Checklist**:

- [ ] Vault pod is in `Running` state
- [ ] Vault is unsealed (`Sealed: false`)
- [ ] Both services (`vault` and `vault-ui`) exist
- [ ] File `vault-credentials.txt` was created

---

### Step 2: Populate Secrets

```bash
make populate-vault
```

**What this does**:

- [x] Generates secure random passwords using `openssl rand -base64`
- [x] Stores secrets in 7 categories:
  - Dragonfly (Redis): password, host, port, connection_url
  - Redpanda (Kafka): admin credentials, SASL credentials
  - ScyllaDB (Cassandra): username, password, keyspace, contact_points
  - user-management: secret_key, jwt_secret
  - Varnish: admin_secret
  - Envoy: admin_port, listener_port
  - Config: environment, log_level

**Verify**:

```bash
# List all secrets
kubectl exec -n adplatform vault-0 -- vault kv list secret/adplatform

# Should show:
# dragonfly/
# redpanda/
# scylla/
# user-management/
# varnish/
# envoy/
# config/

# Read a specific secret
kubectl exec -n adplatform vault-0 -- \
  vault kv get secret/adplatform/user-management
```

**Checklist**:

- [ ] All 7 secret categories were created
- [ ] Can list secrets with `vault kv list`
- [ ] Can read a specific secret with `vault kv get`
- [ ] Passwords look sufficiently random and complex

---

### Step 3: Secure Credentials

```bash
# View credentials
cat vault-credentials.txt

# Expected format:
# Unseal Key: <base64-key>
# Root Token: s.<token>
```

**Actions**:

1. [ ] Open `vault-credentials.txt`
2. [ ] Copy **Unseal Key** to secure password manager (e.g., 1Password, LastPass)
3. [ ] Copy **Root Token** to secure password manager
4. [ ] Label these as "Vault Unseal Key" and "Vault Root Token"
5. [ ] Add note: "For adplatform namespace, created on [date]"
6. [ ] **DELETE** `vault-credentials.txt`:
   ```bash
   rm vault-credentials.txt
   ```
7. [ ] Verify file is deleted:
   ```bash
   ls vault-credentials.txt
   # Should show: No such file or directory
   ```

**⚠️ CRITICAL**: The unseal key and root token are the keys to your secrets. If lost, you cannot unseal Vault. If leaked, attackers can access all secrets.

---

### Step 4: Access Vault UI

```bash
# Port-forward to Vault UI
make vault-ui

# Keep this terminal open
```

**In a new terminal/browser**:

1. [ ] Open http://localhost:8200
2. [ ] Select authentication method: "Token"
3. [ ] Enter root token from password manager
4. [ ] Click "Sign in"
5. [ ] Navigate to `secret/` → `adplatform/`
6. [ ] Verify all secrets are present
7. [ ] Click on `user-management` → verify `jwt_secret` and `secret_key` exist

**Checklist**:

- [ ] Vault UI loads successfully
- [ ] Can log in with root token
- [ ] Can see `secret/adplatform/` path
- [ ] All 7 service categories visible
- [ ] Secrets have values (not empty)

**When done**: Press `Ctrl+C` in the terminal running `make vault-ui`

---

## Application Integration

### Step 5: Choose Integration Method

Choose **one** of these approaches:

#### Option A: Vault Agent Sidecar (Recommended for Quick Start)

**Pros**: Easiest, no code changes  
**Cons**: Extra container overhead

**Example**: See `k8s/user-management-deployment-vault.yaml`

**Steps**:

1. [ ] Add annotations to deployment (see `VAULT_INTEGRATION.md`)
2. [ ] Add `serviceAccountName: vault-auth` to pod spec
3. [ ] Update container command to source `/vault/secrets/*`
4. [ ] Apply updated deployment: `kubectl apply -f k8s/your-deployment.yaml`

#### Option B: Direct Vault API (Recommended for Production)

**Pros**: Efficient, native integration  
**Cons**: Requires code changes

**Example**: See `user-management/src/vault.rs`

**Steps**:

1. [ ] Add dependencies to `Cargo.toml` (reqwest, tokio, serde_json)
2. [ ] Add `vault.rs` module to your application
3. [ ] Update `main.rs` to call `vault::load_config().await`
4. [ ] Add environment variables: `VAULT_ADDR`, `VAULT_ROLE`
5. [ ] Add `serviceAccountName: vault-auth` to deployment
6. [ ] Build new Docker image
7. [ ] Push to registry
8. [ ] Apply updated deployment

**Checklist**:

- [ ] Chose integration method
- [ ] Reviewed example for chosen method
- [ ] Understood the implementation

---

### Step 6: Update user-management Service

**For Sidecar Approach**:

```bash
# Backup current deployment
cp k8s/user-management-deployment.yaml k8s/user-management-deployment.backup

# Use the Vault-enabled version
cp k8s/user-management-deployment-vault.yaml k8s/user-management-deployment.yaml

# Apply
kubectl apply -f k8s/user-management-deployment.yaml

# Wait for rollout
kubectl rollout status deployment/user-management -n adplatform
```

**For Direct API Approach**:

```bash
# Build new image with Vault integration
cd user-management
docker build -t orazesen/user-management:vault .
docker push orazesen/user-management:vault

# Update deployment
kubectl set image deployment/user-management \
  user-management=orazesen/user-management:vault \
  -n adplatform

# Wait for rollout
kubectl rollout status deployment/user-management -n adplatform
```

**Verify**:

```bash
# Check pod has correct containers
kubectl get pods -n adplatform -l app=user-management

# For sidecar: Should show 2/2 (app + vault-agent)
# For direct API: Should show 1/1 (app only)

# Check logs
kubectl logs -n adplatform -l app=user-management --tail=50

# For sidecar: Look for vault-agent logs
# For direct API: Look for "Loading configuration from Vault" messages

# Test the service
kubectl port-forward -n adplatform svc/user-management 8080:8080
curl http://localhost:8080/healthz
# Expected: {"status":"ok"}
```

**Checklist**:

- [ ] Pod started successfully
- [ ] Logs show successful Vault authentication
- [ ] No errors in logs
- [ ] Service responds to health check
- [ ] Service has access to secrets

---

### Step 7: Update Remaining Services

Repeat Step 6 for each service that needs secrets:

#### Dragonfly (Redis)

- [ ] Update deployment to fetch `secret/adplatform/dragonfly/password`
- [ ] Apply: `kubectl apply -f k8s/dragonfly-deployment.yaml`
- [ ] Verify: `kubectl logs -n adplatform -l app=dragonfly`

#### Redpanda (Kafka)

- [ ] Update StatefulSet to fetch `secret/adplatform/redpanda/*`
- [ ] Apply: `kubectl apply -f k8s/redpanda-statefulset.yaml`
- [ ] Verify: `kubectl logs -n adplatform -l app=redpanda`

#### ScyllaDB (Cassandra)

- [ ] Update StatefulSet to fetch `secret/adplatform/scylla/*`
- [ ] Apply: `kubectl apply -f k8s/scylla-statefulset.yaml`
- [ ] Verify: `kubectl logs -n adplatform -l app=scylla`

#### Varnish (Cache)

- [ ] Update deployment to fetch `secret/adplatform/varnish/admin_secret`
- [ ] Apply: `kubectl apply -f k8s/varnish-deployment.yaml`
- [ ] Verify: `kubectl logs -n adplatform -l app=varnish`

#### Envoy (Proxy)

- [ ] Update deployment if needed (mostly static config)
- [ ] Apply: `kubectl apply -f k8s/envoy-deployment.yaml`
- [ ] Verify: `kubectl logs -n adplatform -l app=envoy`

---

## Post-Deployment Verification

### Step 8: End-to-End Testing

```bash
# Test Envoy → Varnish → user-management flow
kubectl port-forward -n adplatform svc/envoy 8080:80

# In another terminal:
curl http://localhost:8080/
# Expected: "user-management ok"

curl http://localhost:8080/healthz
# Expected: {"status":"ok"}
```

**Checklist**:

- [ ] All pods are running
- [ ] All services can authenticate with Vault
- [ ] Application can fetch and use secrets
- [ ] End-to-end request flow works
- [ ] No errors in any pod logs

---

### Step 9: Test Secret Retrieval

```bash
# Use the helper script
make get-secret SECRET_PATH=adplatform/user-management FIELD=jwt_secret

# Expected: Displays the JWT secret value

# Try retrieving all fields
make get-secret SECRET_PATH=adplatform/user-management

# Expected: Displays JSON with all fields
```

**Checklist**:

- [ ] Can retrieve secrets using `make get-secret`
- [ ] JSON output is valid
- [ ] Secret values match what you see in Vault UI

---

### Step 10: Test Secret Rotation

```bash
# Update a secret
kubectl exec -n adplatform vault-0 -- \
  vault kv put secret/adplatform/user-management \
  jwt_secret="new-test-secret-$(date +%s)" \
  secret_key="new-key-$(date +%s)"

# Restart the application to pick up new secrets
kubectl rollout restart deployment/user-management -n adplatform

# Wait for rollout
kubectl rollout status deployment/user-management -n adplatform

# Verify new secrets are loaded
kubectl logs -n adplatform -l app=user-management --tail=20
# Look for: "Configuration loaded successfully from Vault"
```

**Checklist**:

- [ ] Can update secrets in Vault
- [ ] Application restarts successfully
- [ ] Application loads new secrets
- [ ] No errors during rotation

---

## Troubleshooting Checks

### If Vault is Sealed

```bash
# Check status
kubectl exec -n adplatform vault-0 -- vault status

# If sealed, unseal with key from password manager
kubectl exec -n adplatform vault-0 -- \
  vault operator unseal <unseal-key-from-password-manager>
```

### If Application Can't Authenticate

```bash
# Check ServiceAccount exists
kubectl get sa vault-auth -n adplatform

# Check role binding in Vault
kubectl exec -n adplatform vault-0 -- \
  vault read auth/kubernetes/role/adplatform

# Check policy
kubectl exec -n adplatform vault-0 -- \
  vault policy read adplatform-policy

# Check application has correct ServiceAccount
kubectl get pod -n adplatform <pod-name> -o yaml | grep serviceAccount
```

### If Secrets Not Found

```bash
# List all secrets
kubectl exec -n adplatform vault-0 -- \
  vault kv list secret/adplatform

# Read specific secret
kubectl exec -n adplatform vault-0 -- \
  vault kv get secret/adplatform/user-management

# If missing, re-run populate script
make populate-vault
```

---

## Production Readiness Checklist

Before going to production, ensure these are addressed:

### Security

- [ ] Enable TLS for Vault communication (not HTTP)
- [ ] Implement auto-unseal with cloud KMS (AWS/Azure/GCP)
- [ ] Rotate root token and store in secure location
- [ ] Enable audit logging: `vault audit enable file file_path=/vault/audit/vault_audit.log`
- [ ] Review and harden policies (principle of least privilege)
- [ ] Set up secret rotation schedule (every 90 days recommended)
- [ ] Configure network policies to restrict Vault access

### High Availability

- [ ] Deploy Vault in HA mode (3+ replicas)
- [ ] Use Consul or etcd as storage backend (not file)
- [ ] Set up load balancing for Vault replicas
- [ ] Test failover scenarios

### Monitoring

- [ ] Integrate with Prometheus for metrics
- [ ] Set up Grafana dashboards for Vault
- [ ] Configure alerts for:
  - Vault sealed
  - Authentication failures
  - Token expiration warnings
  - Storage usage
- [ ] Monitor audit logs for suspicious activity

### Backup & Recovery

- [ ] Document backup procedures
- [ ] Test restore procedures
- [ ] Automate backups (script or CronJob)
- [ ] Store backups in separate location
- [ ] Test disaster recovery plan

### Documentation

- [ ] Document unseal procedure
- [ ] Document secret rotation procedure
- [ ] Document emergency access procedure
- [ ] Document application integration patterns
- [ ] Create runbook for common operations

---

## Cleanup (if needed)

To completely remove Vault:

```bash
# Delete Vault resources
kubectl delete -f k8s/vault-deployment.yaml
kubectl delete -f k8s/vault-rbac.yaml

# Delete PVC (will delete all secrets!)
kubectl delete pvc vault-pvc -n adplatform

# Remove local credentials file (if not already deleted)
rm -f vault-credentials.txt
```

**⚠️ WARNING**: This will **permanently delete all secrets**. Only do this if you're certain!

---

## Success Criteria

Your Vault deployment is successful when:

✅ **Infrastructure**:

- [ ] Vault pod is running and unsealed
- [ ] Both services (vault, vault-ui) are accessible
- [ ] PersistentVolume is bound and storing data
- [ ] RBAC is configured correctly

✅ **Secrets**:

- [ ] All 7 secret categories exist
- [ ] Secrets have strong, random values
- [ ] Can retrieve secrets via API and UI
- [ ] Credentials are secured in password manager

✅ **Applications**:

- [ ] All applications can authenticate with Vault
- [ ] Applications can fetch required secrets
- [ ] Applications function correctly with Vault secrets
- [ ] No hardcoded credentials in code or configs

✅ **Operations**:

- [ ] Can unseal Vault manually if needed
- [ ] Can rotate secrets and restart applications
- [ ] Can add new secrets as needed
- [ ] Team understands how to use Vault

---

## Next Steps After Successful Deployment

1. **Security Review**:

   - Review who has access to root token
   - Create additional policies for different teams
   - Set up MFA for Vault UI access

2. **Monitoring Setup**:

   - Install Prometheus ServiceMonitor for Vault
   - Create Grafana dashboards
   - Set up alerts

3. **Documentation**:

   - Update team documentation with Vault procedures
   - Create training materials for developers
   - Document secret rotation schedule

4. **Migration**:

   - Identify remaining hardcoded secrets
   - Migrate them to Vault
   - Remove old environment variables

5. **Production Hardening**:
   - Follow production checklist above
   - Implement auto-unseal
   - Set up HA mode
   - Enable audit logging

---

**Congratulations!** 🎉

You've successfully deployed HashiCorp Vault and migrated from `.env` files to enterprise-grade secrets management.

For questions or issues:

- See `VAULT_GUIDE.md` for comprehensive documentation
- See `VAULT_INTEGRATION.md` for application integration details
- See `VAULT_ARCHITECTURE.md` for architecture diagrams
- Check Vault logs: `kubectl logs -n adplatform vault-0`
