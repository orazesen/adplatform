# HashiCorp Vault Integration Guide

## Overview

This project uses HashiCorp Vault for secure secrets management. All credentials, API keys, and sensitive configuration are stored in Vault instead of environment variables or Kubernetes secrets.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                       │
│                                                              │
│  ┌──────────────┐      ┌──────────────┐                   │
│  │   Vault      │◄─────┤ Applications │                   │
│  │   Server     │      │  (Sidecars)  │                   │
│  └──────────────┘      └──────────────┘                   │
│         │                                                   │
│         │ Stores Secrets                                   │
│         ▼                                                   │
│  ┌──────────────┐                                          │
│  │ Persistent   │                                          │
│  │   Storage    │                                          │
│  └──────────────┘                                          │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Deploy Vault

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Deploy and initialize Vault
./scripts/setup-vault.sh
```

This will:

- Deploy Vault to the `adplatform` namespace
- Initialize Vault with a single unseal key
- Configure Kubernetes authentication
- Create policies and roles for applications
- Save credentials to `vault-credentials.txt`

**⚠️ IMPORTANT:** Save the unseal key and root token from `vault-credentials.txt` in a secure password manager, then delete the file!

### 2. Populate Secrets

```bash
# Add all application secrets to Vault
./scripts/populate-vault-secrets.sh
```

This generates and stores:

- Dragonfly (Redis) credentials
- Redpanda (Kafka) credentials
- ScyllaDB (Cassandra) credentials
- User Management service secrets
- Varnish admin secrets
- Application configuration

### 3. Access Vault UI

```bash
# Forward Vault UI port
kubectl port-forward -n adplatform svc/vault-ui 8200:8200

# Open browser to http://localhost:8200
# Login with the root token from vault-credentials.txt
```

## Secrets Structure

All secrets are stored under the `secret/adplatform/` path:

```
secret/adplatform/
├── dragonfly/
│   ├── password
│   ├── host
│   ├── port
│   └── connection_url
├── redpanda/
│   ├── admin_user
│   ├── admin_password
│   ├── sasl_username
│   ├── sasl_password
│   ├── brokers
│   └── admin_api
├── scylla/
│   ├── username
│   ├── password
│   ├── keyspace
│   ├── hosts
│   └── port
├── user-management/
│   ├── secret_key
│   ├── jwt_secret
│   ├── jwt_expiration_hours
│   └── port
├── varnish/
│   ├── admin_secret
│   ├── port
│   └── admin_port
├── envoy/
│   ├── admin_port
│   └── listener_port
└── config/
    ├── app_env
    ├── log_level
    ├── rust_log
    ├── metrics_port
    ├── tracing_enabled
    ├── cors_allowed_origins
    └── api_rate_limit
```

## Retrieving Secrets

### From Command Line

```bash
# Get all secrets for a service
./scripts/get-vault-secret.sh adplatform/dragonfly

# Get a specific field
./scripts/get-vault-secret.sh adplatform/dragonfly password

# Or use vault CLI directly
kubectl exec -n adplatform <vault-pod> -- vault kv get secret/adplatform/dragonfly
```

### From Applications (Kubernetes)

Applications can retrieve secrets using:

1. **Vault Agent Sidecar** (Recommended)
2. **Direct API calls with Kubernetes auth**
3. **Vault CSI Provider**

#### Option 1: Vault Agent Sidecar (Recommended)

Add annotations to your deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-management
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "adplatform"
        vault.hashicorp.com/agent-inject-secret-db: "secret/data/adplatform/dragonfly"
        vault.hashicorp.com/agent-inject-template-db: |
          {{- with secret "secret/data/adplatform/dragonfly" -}}
          export REDIS_PASSWORD="{{ .Data.data.password }}"
          export REDIS_HOST="{{ .Data.data.host }}"
          {{- end }}
    spec:
      serviceAccountName: vault-auth
      containers:
        - name: app
          # Your application container
```

#### Option 2: Direct API Calls

```rust
// Example Rust code to fetch secrets from Vault
use reqwest;
use serde_json::Value;

async fn get_secret(path: &str) -> Result<Value, Box<dyn std::error::Error>> {
    let vault_addr = std::env::var("VAULT_ADDR")?;
    let vault_token = std::env::var("VAULT_TOKEN")?;

    let url = format!("{}/v1/secret/data/{}", vault_addr, path);
    let client = reqwest::Client::new();

    let response = client
        .get(&url)
        .header("X-Vault-Token", vault_token)
        .send()
        .await?
        .json::<Value>()
        .await?;

    Ok(response["data"]["data"].clone())
}

// Usage
let dragonfly_password = get_secret("adplatform/dragonfly")
    .await?["password"]
    .as_str()
    .unwrap();
```

## Common Operations

### Unsealing Vault

Vault needs to be unsealed after every restart:

```bash
VAULT_POD=$(kubectl get pods -n adplatform -l app=vault -o jsonpath='{.items[0].metadata.name}')
UNSEAL_KEY="<your-unseal-key>"

kubectl exec -n adplatform $VAULT_POD -- vault operator unseal $UNSEAL_KEY
```

### Updating Secrets

```bash
# Update a specific secret
kubectl exec -n adplatform <vault-pod> -- vault kv put secret/adplatform/dragonfly \
    password="new_password" \
    host="dragonfly" \
    port="6379"

# Or patch a single field
kubectl exec -n adplatform <vault-pod> -- vault kv patch secret/adplatform/dragonfly \
    password="new_password"
```

### Rotating Credentials

```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32 | tr -d '=/+' | cut -c1-32)

# Update in Vault
kubectl exec -n adplatform <vault-pod> -- vault kv patch secret/adplatform/dragonfly \
    password="$NEW_PASSWORD"

# Restart affected pods
kubectl rollout restart deployment/dragonfly -n adplatform
```

### Backup Vault Data

```bash
# Backup vault data volume
kubectl exec -n adplatform <vault-pod> -- tar czf /tmp/vault-backup.tar.gz /vault/data

kubectl cp adplatform/<vault-pod>:/tmp/vault-backup.tar.gz ./vault-backup-$(date +%Y%m%d).tar.gz
```

### List All Secrets

```bash
kubectl exec -n adplatform <vault-pod> -- vault kv list secret/adplatform
```

## Security Best Practices

### 1. Protect Root Token

- Never commit the root token to version control
- Store it in a password manager
- Use it only for initial setup
- Create service-specific tokens with limited policies

### 2. Rotate Credentials Regularly

- Database passwords: Every 90 days
- API keys: Every 90 days
- JWT secrets: Every 180 days

### 3. Use Least Privilege

- Applications should only access secrets they need
- Create separate policies for each service
- Use Kubernetes auth for pod authentication

### 4. Enable Audit Logging (Production)

```bash
kubectl exec -n adplatform <vault-pod> -- vault audit enable file file_path=/vault/logs/audit.log
```

### 5. Use Vault in HA Mode (Production)

For production, use Vault with:

- Multiple replicas
- Consul or etcd backend
- TLS enabled
- Auto-unseal with cloud KMS

## Monitoring

### Check Vault Status

```bash
kubectl exec -n adplatform <vault-pod> -- vault status
```

### View Audit Logs

```bash
kubectl logs -n adplatform <vault-pod> -f
```

### Health Check

```bash
curl http://localhost:8200/v1/sys/health
```

## Troubleshooting

### Vault is Sealed

```bash
# Check seal status
kubectl exec -n adplatform <vault-pod> -- vault status

# Unseal
kubectl exec -n adplatform <vault-pod> -- vault operator unseal <unseal-key>
```

### Can't Access Secrets

```bash
# Check Kubernetes auth
kubectl exec -n adplatform <vault-pod> -- vault read auth/kubernetes/config

# Check policy
kubectl exec -n adplatform <vault-pod> -- vault policy read adplatform-policy

# Test authentication
kubectl exec -n adplatform <vault-pod> -- vault login <token>
```

### Pod Can't Authenticate

```bash
# Verify service account
kubectl get sa vault-auth -n adplatform

# Check role binding
kubectl exec -n adplatform <vault-pod> -- vault read auth/kubernetes/role/adplatform
```

## Migration from .env Files

If you previously used `.env` files:

1. **Export existing secrets** to a temporary location
2. **Run populate-vault-secrets.sh** to generate new secure credentials
3. **Update applications** to fetch from Vault instead of environment variables
4. **Delete .env files** and ensure they're in `.gitignore`

## Production Considerations

For production deployments:

1. **Use Vault Enterprise or Cloud** for advanced features
2. **Enable TLS** for all Vault communication
3. **Use auto-unseal** with AWS KMS, Azure Key Vault, or Google Cloud KMS
4. **Deploy in HA mode** with 3+ replicas
5. **Use Consul or etcd** for storage backend (not file)
6. **Enable audit logging** to monitor all access
7. **Set up disaster recovery** with regular backups
8. **Implement secret rotation** policies
9. **Use namespace isolation** for multi-tenant setups
10. **Monitor Vault metrics** with Prometheus

## Additional Resources

- [Vault Documentation](https://www.vaultproject.io/docs)
- [Kubernetes Auth Method](https://www.vaultproject.io/docs/auth/kubernetes)
- [Vault Agent](https://www.vaultproject.io/docs/agent)
- [KV Secrets Engine](https://www.vaultproject.io/docs/secrets/kv/kv-v2)
