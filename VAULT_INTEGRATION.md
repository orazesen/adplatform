# Vault Integration Guide - Application Updates

This guide shows how to update your applications to fetch secrets from HashiCorp Vault instead of environment variables.

## Table of Contents

1. [Quick Deployment](#quick-deployment)
2. [Two Integration Approaches](#two-integration-approaches)
3. [Approach 1: Vault Agent Sidecar (Recommended for Quick Start)](#approach-1-vault-agent-sidecar)
4. [Approach 2: Direct Vault API (Recommended for Production)](#approach-2-direct-vault-api)
5. [Deployment Order](#deployment-order)
6. [Testing](#testing)
7. [Troubleshooting](#troubleshooting)

---

## Quick Deployment

### Step 1: Deploy and Initialize Vault

```bash
# Deploy Vault and initialize it
make setup-vault

# This will:
# - Deploy Vault to Kubernetes
# - Initialize with unseal key
# - Configure Kubernetes authentication
# - Save credentials to vault-credentials.txt
```

### Step 2: Populate Secrets

```bash
# Generate and store all application secrets
make populate-vault

# This stores secrets for:
# - Dragonfly (Redis)
# - Redpanda (Kafka)
# - ScyllaDB (Cassandra)
# - user-management (JWT secrets)
# - Varnish (admin secret)
# - Envoy (configuration)
# - App config (general settings)
```

### Step 3: Secure Your Credentials

```bash
# Save these to your password manager, then delete the file!
cat vault-credentials.txt

# Copy to password manager, then:
rm vault-credentials.txt
```

### Step 4: Access Vault UI

```bash
# Port-forward to Vault UI
make vault-ui

# Open browser: http://localhost:8200
# Login with root token from vault-credentials.txt
```

---

## Two Integration Approaches

### Comparison

| Feature               | Vault Agent Sidecar      | Direct Vault API               |
| --------------------- | ------------------------ | ------------------------------ |
| **Setup Complexity**  | Low (just annotations)   | Medium (requires code changes) |
| **Code Changes**      | Minimal                  | Moderate                       |
| **Dependencies**      | None                     | Add reqwest, tokio, etc.       |
| **Secret Updates**    | Manual pod restart       | Automatic on restart           |
| **Best For**          | Quick start, simple apps | Production, complex apps       |
| **Performance**       | Extra sidecar overhead   | Direct, efficient              |
| **Kubernetes Native** | Yes                      | Yes                            |

**Recommendation**: Start with Sidecar for quick deployment, migrate to Direct API for production.

---

## Approach 1: Vault Agent Sidecar

The Vault Agent Injector automatically injects a sidecar container that fetches secrets and writes them to files in `/vault/secrets/`.

### How It Works

1. Add annotations to your deployment
2. Vault Injector sees the annotations and injects a sidecar
3. Sidecar authenticates with Vault using Kubernetes ServiceAccount
4. Sidecar fetches secrets and writes to `/vault/secrets/`
5. Your app sources the secrets from files

### Example: user-management Deployment

See `k8s/user-management-deployment-vault.yaml` for the complete example.

Key annotations:

```yaml
annotations:
  # Enable Vault injection
  vault.hashicorp.com/agent-inject: "true"

  # Use the 'adplatform' role we created
  vault.hashicorp.com/role: "adplatform"

  # Inject secret at /vault/secrets/jwt
  vault.hashicorp.com/agent-inject-secret-jwt: "secret/data/adplatform/user-management"

  # Template the secret as environment variables
  vault.hashicorp.com/agent-inject-template-jwt: |
    {{- with secret "secret/data/adplatform/user-management" -}}
    export JWT_SECRET="{{ .Data.data.jwt_secret }}"
    export SECRET_KEY="{{ .Data.data.secret_key }}"
    {{- end -}}
```

### Applying the Sidecar Approach

1. **Update your deployment**:

   ```bash
   # Replace the old deployment
   cp k8s/user-management-deployment-vault.yaml k8s/user-management-deployment.yaml
   kubectl apply -f k8s/user-management-deployment.yaml
   ```

2. **Verify the injection**:

   ```bash
   # Check that the sidecar was injected
   kubectl get pods -n adplatform -l app=user-management

   # Should show 2/2 containers (app + vault-agent)
   ```

3. **Check secrets are available**:
   ```bash
   POD=$(kubectl get pods -n adplatform -l app=user-management -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -n adplatform $POD -c user-management -- cat /vault/secrets/jwt
   ```

### Updating Other Deployments

**Dragonfly Example**:

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "adplatform"
  vault.hashicorp.com/agent-inject-secret-redis: "secret/data/adplatform/dragonfly"
  vault.hashicorp.com/agent-inject-template-redis: |
    {{- with secret "secret/data/adplatform/dragonfly" -}}
    export REDIS_PASSWORD="{{ .Data.data.password }}"
    {{- end -}}
```

**Redpanda Example**:

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "adplatform"
  vault.hashicorp.com/agent-inject-secret-kafka: "secret/data/adplatform/redpanda"
  vault.hashicorp.com/agent-inject-template-kafka: |
    {{- with secret "secret/data/adplatform/redpanda" -}}
    export KAFKA_SASL_USERNAME="{{ .Data.data.sasl_username }}"
    export KAFKA_SASL_PASSWORD="{{ .Data.data.sasl_password }}"
    {{- end -}}
```

---

## Approach 2: Direct Vault API

In this approach, your application code directly calls the Vault API to fetch secrets at startup.

### How It Works

1. Your app reads the Kubernetes ServiceAccount token from `/var/run/secrets/kubernetes.io/serviceaccount/token`
2. App calls Vault's Kubernetes auth endpoint with the token
3. Vault returns a Vault token
4. App uses Vault token to fetch secrets from KV engine
5. App stores secrets in memory or app state

### Example: Rust Implementation

See `user-management/src/vault.rs` for the complete implementation.

#### Key Components

**1. Vault Client** (`vault.rs`):

```rust
pub struct VaultClient {
    vault_addr: String,
    vault_token: Option<String>,
    http_client: reqwest::Client,
}

impl VaultClient {
    // Authenticate using Kubernetes service account
    pub async fn login_kubernetes(&mut self, role: &str, jwt_path: &str)
        -> Result<(), Box<dyn Error>>

    // Get secrets from KV-v2 engine
    pub async fn get_secret(&self, path: &str)
        -> Result<VaultConfig, Box<dyn Error>>
}
```

**2. Configuration Loading** (`vault.rs`):

```rust
pub async fn load_config() -> Result<VaultConfig, Box<dyn Error>> {
    let vault_addr = std::env::var("VAULT_ADDR")
        .unwrap_or_else(|_| "http://vault:8200".to_string());
    let vault_role = std::env::var("VAULT_ROLE")
        .unwrap_or_else(|_| "adplatform".to_string());

    let mut vault_client = VaultClient::new(vault_addr);
    vault_client.login_kubernetes(&vault_role,
        "/var/run/secrets/kubernetes.io/serviceaccount/token").await?;

    vault_client.get_user_management_config().await
}
```

**3. Using in main.rs** (see `main-vault-example.rs`):

```rust
mod vault;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init();

    // Load configuration from Vault
    let config = vault::load_config().await
        .expect("Failed to load configuration from Vault");

    log::info!("Configuration loaded from Vault");

    // Use config.jwt_secret and config.secret_key in your app
    // ...
}
```

### Implementing in Your Application

#### Step 1: Add Dependencies

Update `Cargo.toml`:

```toml
[dependencies]
actix-web = "4"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
env_logger = "0.10"
reqwest = { version = "0.11", features = ["json"] }
tokio = { version = "1", features = ["full"] }
log = "0.4"
```

#### Step 2: Add Vault Module

Copy `vault.rs` to your `src/` directory, or copy the relevant parts into your existing modules.

#### Step 3: Update main.rs

```rust
mod vault;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init();

    // Load config from Vault
    let config = vault::load_config().await
        .expect("Failed to load configuration from Vault");

    // Use config in your application
    // For example, set up JWT middleware:
    // let jwt_middleware = JwtMiddleware::new(&config.jwt_secret);

    HttpServer::new(move || {
        App::new()
            // Use config here
            .service(your_routes)
    })
    .bind("0.0.0.0:8080")?
    .run()
    .await
}
```

#### Step 4: Update Deployment

Ensure your deployment has the `vault-auth` ServiceAccount:

```yaml
spec:
  serviceAccountName: vault-auth
  containers:
    - name: user-management
      env:
        - name: VAULT_ADDR
          value: "http://vault:8200"
        - name: VAULT_ROLE
          value: "adplatform"
```

#### Step 5: Build and Deploy

```bash
# Build the updated image
cd user-management
docker build -t orazesen/user-management:vault .

# Push to registry
docker push orazesen/user-management:vault

# Update deployment to use new image
kubectl set image deployment/user-management \
  user-management=orazesen/user-management:vault \
  -n adplatform

# Or update the deployment YAML and apply
kubectl apply -f k8s/user-management-deployment.yaml
```

### Adapting for Other Languages

**Python Example**:

```python
import hvac
import os

def load_config():
    vault_addr = os.getenv('VAULT_ADDR', 'http://vault:8200')
    vault_role = os.getenv('VAULT_ROLE', 'adplatform')

    # Read Kubernetes service account token
    with open('/var/run/secrets/kubernetes.io/serviceaccount/token') as f:
        jwt = f.read()

    # Authenticate
    client = hvac.Client(url=vault_addr)
    response = client.auth.kubernetes.login(
        role=vault_role,
        jwt=jwt
    )

    # Get secrets
    secret = client.secrets.kv.v2.read_secret_version(
        path='adplatform/user-management'
    )

    return secret['data']['data']
```

**Go Example**:

```go
import (
    "github.com/hashicorp/vault/api"
    "io/ioutil"
)

func loadConfig() (map[string]interface{}, error) {
    config := api.DefaultConfig()
    config.Address = os.Getenv("VAULT_ADDR")

    client, err := api.NewClient(config)
    if err != nil {
        return nil, err
    }

    // Read JWT token
    jwt, err := ioutil.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/token")
    if err != nil {
        return nil, err
    }

    // Authenticate
    data := map[string]interface{}{
        "role": "adplatform",
        "jwt":  string(jwt),
    }
    secret, err := client.Logical().Write("auth/kubernetes/login", data)
    client.SetToken(secret.Auth.ClientToken)

    // Get secrets
    secret, err = client.Logical().Read("secret/data/adplatform/user-management")
    return secret.Data["data"].(map[string]interface{}), nil
}
```

---

## Deployment Order

Follow this order to ensure smooth deployment:

1. **Deploy Vault**:

   ```bash
   make setup-vault
   ```

2. **Populate Secrets**:

   ```bash
   make populate-vault
   ```

3. **Update Backing Services First** (they don't depend on others):

   ```bash
   # Update Dragonfly to use Vault password
   kubectl apply -f k8s/dragonfly-deployment.yaml

   # Update ScyllaDB to use Vault credentials
   kubectl apply -f k8s/scylla-statefulset.yaml

   # Update Redpanda to use Vault SASL credentials
   kubectl apply -f k8s/redpanda-statefulset.yaml
   ```

4. **Update Application Services**:

   ```bash
   # Update user-management
   kubectl apply -f k8s/user-management-deployment.yaml

   # Update other application services
   ```

5. **Update Proxies Last**:

   ```bash
   # Update Varnish
   kubectl apply -f k8s/varnish-deployment.yaml

   # Update Envoy
   kubectl apply -f k8s/envoy-deployment.yaml
   ```

---

## Testing

### Test Vault Connectivity

```bash
# From inside a pod with vault-auth ServiceAccount
kubectl run -it --rm debug \
  --image=hashicorp/vault:1.15 \
  --serviceaccount=vault-auth \
  --namespace=adplatform \
  -- sh

# Inside the pod:
export VAULT_ADDR=http://vault:8200
export JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# Login
vault write auth/kubernetes/login role=adplatform jwt=$JWT

# Read a secret (use token from previous command)
export VAULT_TOKEN=<token-from-previous-command>
vault kv get secret/adplatform/user-management
```

### Test Application with Vault

```bash
# Check application logs for Vault authentication
kubectl logs -n adplatform -l app=user-management --tail=50

# Should see logs like:
# INFO Loading configuration from Vault...
# INFO Configuration loaded successfully from Vault
```

### Verify Secrets in Application

```bash
# If using sidecar approach, check the injected files
POD=$(kubectl get pods -n adplatform -l app=user-management -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n adplatform $POD -c user-management -- cat /vault/secrets/jwt

# Should show exported environment variables
```

---

## Troubleshooting

### Issue: "Vault is sealed"

**Symptoms**: Applications can't fetch secrets, logs show "Vault is sealed"

**Solution**:

```bash
# Unseal Vault
make vault-ui
# In another terminal:
vault operator unseal <unseal-key-from-vault-credentials.txt>
```

### Issue: "Permission denied"

**Symptoms**: Application logs show "permission denied" when accessing secrets

**Solution**:

```bash
# Check the policy
kubectl exec -n adplatform vault-0 -- \
  vault policy read adplatform-policy

# Should allow read access to secret/data/adplatform/*

# Check the role binding
kubectl exec -n adplatform vault-0 -- \
  vault read auth/kubernetes/role/adplatform

# Should be bound to vault-auth ServiceAccount
```

### Issue: "Connection refused" to Vault

**Symptoms**: Application can't connect to Vault at http://vault:8200

**Solution**:

```bash
# Verify Vault service exists
kubectl get svc -n adplatform vault

# Verify Vault pods are running
kubectl get pods -n adplatform -l app=vault

# Check if application is using correct VAULT_ADDR
kubectl describe pod -n adplatform <your-pod>
```

### Issue: Sidecar not injected

**Symptoms**: Pod only has 1 container instead of 2

**Solution**:

```bash
# Check if Vault Agent Injector is running
kubectl get pods -n vault-system

# If not installed, install Vault with Helm:
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault \
  --namespace adplatform \
  --set "injector.enabled=true"
```

### Issue: Secrets not updating after rotation

**Symptoms**: Application still using old secrets after updating in Vault

**Solution**:

```bash
# For sidecar approach: Restart pods
kubectl rollout restart deployment/user-management -n adplatform

# For direct API approach: Application needs to implement refresh logic
# or simply restart the pods as above
```

---

## Next Steps

1. **Deploy Vault**: Run `make setup-vault`
2. **Populate Secrets**: Run `make populate-vault`
3. **Choose Integration Approach**: Start with Sidecar for simplicity
4. **Update One Service**: Start with user-management as the example
5. **Test Thoroughly**: Verify secret retrieval works
6. **Update Remaining Services**: Apply to Dragonfly, Redpanda, etc.
7. **Production Hardening**: See VAULT_GUIDE.md for production considerations

For more details:

- See `VAULT_GUIDE.md` for comprehensive Vault documentation
- See `k8s/user-management-deployment-vault.yaml` for sidecar example
- See `user-management/src/vault.rs` for direct API implementation
- Run `make help` to see all available Vault commands
