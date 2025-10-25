# Architecture with HashiCorp Vault

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           External Traffic                                   │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │ HTTP :80
                                   ▼
                    ┌──────────────────────────┐
                    │        Envoy Proxy       │
                    │    (LoadBalancer)        │
                    │  - Ingress routing       │
                    │  - Load balancing        │
                    └────────────┬─────────────┘
                                 │ HTTP
                                 ▼
                    ┌──────────────────────────┐
                    │      Varnish Cache       │
                    │    (ClusterIP)           │
                    │  - HTTP caching          │
                    │  - Cache invalidation    │
                    └────────────┬─────────────┘
                                 │ HTTP :8080
                                 ▼
                    ┌──────────────────────────┐
                    │   user-management        │◄───────────┐
                    │    (Rust/Actix)          │            │
                    │  - REST API              │            │
                    │  - Business logic        │            │
                    └────┬──────────┬──────────┘            │
                         │          │                        │
            ┌────────────┼──────────┼────────────┐          │
            │            │          │            │          │
            ▼            ▼          ▼            ▼          │
    ┌───────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐
    │ Dragonfly │  │ Redpanda │  │ ScyllaDB │  │  HashiCorp Vault │
    │  (Redis)  │  │ (Kafka)  │  │(Cassandra│  │  (Secrets Mgmt)  │
    │           │  │          │  │          │  │                  │
    │  :6379    │  │  :9092   │  │  :9042   │  │  API: 8200       │
    │           │  │  :19092  │  │  :7000   │  │  UI:  8200       │
    └─────┬─────┘  └────┬─────┘  └────┬─────┘  │  Cluster: 8201   │
          │             │             │         └──────────────────┘
          │             │             │                  ▲
          │             │             │                  │
          └─────────────┴─────────────┴──────────────────┘
                           │
                           │ Fetches secrets using
                           │ Kubernetes authentication
                           │
                           ▼
          ┌─────────────────────────────────────┐
          │    Kubernetes ServiceAccount        │
          │         (vault-auth)                │
          │                                     │
          │  - Token: Auto-mounted at           │
          │    /var/run/secrets/kubernetes.io/  │
          │      serviceaccount/token           │
          │                                     │
          │  - Used by apps to authenticate     │
          │    with Vault                       │
          └─────────────────────────────────────┘
```

## Secret Flow: How Applications Get Secrets

### Method 1: Vault Agent Sidecar (Recommended for Quick Start)

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        Kubernetes Pod                                     │
│                                                                           │
│  ┌────────────────────────────┐    ┌─────────────────────────────────┐  │
│  │   Vault Agent Sidecar      │    │   Application Container         │  │
│  │                            │    │   (user-management)             │  │
│  │  1. Reads SA token         │    │                                 │  │
│  │  2. Authenticates to Vault │    │  4. Sources secrets from        │  │
│  │  3. Fetches secrets        │───►│     /vault/secrets/jwt          │  │
│  │  4. Writes to shared       │    │                                 │  │
│  │     volume                 │    │  5. Starts application with     │  │
│  │                            │    │     secrets loaded              │  │
│  └────────────────────────────┘    └─────────────────────────────────┘  │
│                                                                           │
│  Shared Volume: /vault/secrets/                                          │
│  ├── jwt         (contains: export JWT_SECRET="..." etc.)                │
│  └── ...                                                                  │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
         │                                      ▲
         │ 2. POST /v1/auth/kubernetes/login   │
         │    { role: "adplatform", jwt: "..." }│ Returns Vault token
         │                                      │
         │ 3. GET /v1/secret/data/adplatform/user-management
         │    Header: X-Vault-Token: s.xxxxx
         │                                      │ Returns secrets
         │                                      │
         ▼                                      │
  ┌─────────────────────────────────────────────┐
  │         HashiCorp Vault                     │
  │                                             │
  │  - Validates Kubernetes SA token            │
  │  - Issues Vault token                       │
  │  - Returns requested secrets                │
  └─────────────────────────────────────────────┘
```

### Method 2: Direct API Integration (Recommended for Production)

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        Kubernetes Pod                                     │
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐   │
│  │   Application Container (user-management)                         │   │
│  │                                                                   │   │
│  │   Startup Sequence:                                               │   │
│  │   1. Read SA token from /var/run/secrets/.../token               │   │
│  │   2. Call Vault API: POST /v1/auth/kubernetes/login              │   │
│  │   3. Receive Vault token                                          │   │
│  │   4. Call Vault API: GET /v1/secret/data/adplatform/...          │   │
│  │   5. Store secrets in memory (VaultConfig struct)                │   │
│  │   6. Use secrets throughout application lifecycle                │   │
│  │                                                                   │   │
│  │   Code: see user-management/src/vault.rs                          │   │
│  │                                                                   │   │
│  └───────────────────────────────────────────────────────────────────┘   │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
         │                                      ▲
         │ HTTP Requests to Vault API           │ HTTP Responses
         │                                      │
         ▼                                      │
  ┌─────────────────────────────────────────────┐
  │         HashiCorp Vault                     │
  │                                             │
  │  Service: vault:8200                        │
  │                                             │
  │  Endpoints:                                 │
  │  - POST /v1/auth/kubernetes/login           │
  │  - GET  /v1/secret/data/adplatform/*        │
  │  - PUT  /v1/secret/data/adplatform/*        │
  │  - LIST /v1/secret/metadata/adplatform      │
  └─────────────────────────────────────────────┘
```

## Secret Storage Structure in Vault

```
Vault Server (vault:8200)
│
└── secret/ (KV-v2 engine)
    └── adplatform/
        ├── dragonfly/
        │   ├── password          ──► Used by user-management to connect to Redis
        │   ├── host
        │   ├── port
        │   └── connection_url
        │
        ├── redpanda/
        │   ├── admin_username    ──► Used for Kafka admin operations
        │   ├── admin_password
        │   ├── sasl_username     ──► Used by producers/consumers
        │   └── sasl_password
        │
        ├── scylla/
        │   ├── username          ──► Used for Cassandra connections
        │   ├── password
        │   ├── keyspace
        │   └── contact_points
        │
        ├── user-management/
        │   ├── secret_key        ──► Used for session encryption
        │   └── jwt_secret        ──► Used for JWT token signing
        │
        ├── varnish/
        │   └── admin_secret      ──► Used for Varnish admin interface
        │
        ├── envoy/
        │   ├── admin_port        ──► Configuration values
        │   └── listener_port
        │
        └── config/
            ├── environment       ──► Application configuration
            └── log_level
```

## Authentication Flow

```
1. Pod starts with ServiceAccount "vault-auth"
   │
   │  Kubernetes automatically mounts SA token at:
   │  /var/run/secrets/kubernetes.io/serviceaccount/token
   │
   ▼

2. Application reads SA token
   │
   │  In Rust: std::fs::read_to_string(jwt_path)
   │  In Python: open('/var/run/secrets/.../token').read()
   │
   ▼

3. Application sends auth request to Vault
   │
   │  POST http://vault:8200/v1/auth/kubernetes/login
   │  Body: { "role": "adplatform", "jwt": "<SA-token>" }
   │
   ▼

4. Vault validates the token
   │
   │  - Calls Kubernetes API to verify token
   │  - Checks if ServiceAccount matches role binding
   │  - Checks if namespace is allowed
   │
   ▼

5. Vault issues Vault token
   │
   │  Response: { "auth": { "client_token": "s.xxxxx..." } }
   │  Token has permissions defined by "adplatform-policy"
   │
   ▼

6. Application uses Vault token to fetch secrets
   │
   │  GET http://vault:8200/v1/secret/data/adplatform/user-management
   │  Header: X-Vault-Token: s.xxxxx...
   │
   ▼

7. Vault checks policy and returns secrets
   │
   │  Policy: adplatform-policy allows read on secret/data/adplatform/*
   │  Response: { "data": { "data": { "jwt_secret": "...", ... } } }
   │
   ▼

8. Application uses secrets
   │
   │  - Store in memory (VaultConfig struct)
   │  - Use for JWT signing, database connections, etc.
   │  - Never write to disk
   │
   ✓ Done!
```

## RBAC Configuration

```
Kubernetes Resources:

┌────────────────────────────────────────────────────────────┐
│  ServiceAccount: vault-auth (namespace: adplatform)        │
│  - Used by: user-management, other application pods        │
│  - Has: Auto-mounted token for Kubernetes authentication   │
└────────────────────────────────────────────────────────────┘
                            │
                            │ Bound to
                            ▼
┌────────────────────────────────────────────────────────────┐
│  ClusterRole: vault-token-creator                          │
│  - Can: create tokens                                      │
│  - Resources: serviceaccounts/token                        │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│  ServiceAccount: vault (namespace: adplatform)             │
│  - Used by: Vault server pods                              │
│  - Has: system:auth-delegator permissions                  │
└────────────────────────────────────────────────────────────┘
                            │
                            │ Bound to
                            ▼
┌────────────────────────────────────────────────────────────┐
│  ClusterRole: system:auth-delegator                        │
│  - Can: create tokenreviews (verify K8s tokens)            │
└────────────────────────────────────────────────────────────┘

Vault Configuration:

┌────────────────────────────────────────────────────────────┐
│  Auth Method: kubernetes                                    │
│  - Kubernetes API: https://kubernetes.default.svc          │
│  - Token reviewer JWT: From vault ServiceAccount           │
└────────────────────────────────────────────────────────────┘
                            │
                            │ Has role
                            ▼
┌────────────────────────────────────────────────────────────┐
│  Vault Role: adplatform                                    │
│  - Bound to: vault-auth ServiceAccount                     │
│  - Namespace: adplatform                                   │
│  - Policies: adplatform-policy                             │
│  - TTL: 1 hour                                             │
└────────────────────────────────────────────────────────────┘
                            │
                            │ Grants
                            ▼
┌────────────────────────────────────────────────────────────┐
│  Vault Policy: adplatform-policy                           │
│  - Read: secret/data/adplatform/*                          │
│  - List: secret/metadata/adplatform                        │
└────────────────────────────────────────────────────────────┘
```

## Comparison: Before vs After

### Before (.env approach)

```
Developer's Machine:
  ├── .env (plaintext secrets)
  └── scripts/generate-passwords.sh

        │ git push (risk!)
        ▼

Git Repository:
  └── .env.example (templates only)

        │ git clone
        ▼

CI/CD Pipeline:
  └── Injects .env as ConfigMap or Secret

        │ kubectl apply
        ▼

Kubernetes:
  ├── ConfigMap/Secret (base64 encoded)
  └── Pods mount as environment variables

Issues:
❌ Secrets in plain text on disk
❌ Risk of committing to Git
❌ Manual password generation
❌ No audit trail
❌ Difficult rotation
❌ No centralized management
❌ Base64 is not encryption!
```

### After (Vault approach)

```
Developer's Machine:
  └── scripts/setup-vault.sh (no secrets stored locally)

        │ kubectl apply
        ▼

Kubernetes Cluster:
  ├── Vault Pod (encrypted storage)
  │   ├── PersistentVolume (encrypted at rest)
  │   └── KV-v2 Engine (versioned secrets)
  │
  └── Application Pods
      └── Fetch secrets at runtime via API

        │ Kubernetes auth
        ▼

Vault Server:
  ├── Validates ServiceAccount token
  ├── Issues time-limited Vault token
  ├── Returns secrets over HTTPS
  └── Logs all access (audit)

Benefits:
✅ Secrets encrypted at rest and in transit
✅ Never touch filesystem
✅ Automated password generation
✅ Complete audit trail
✅ Easy rotation (update in Vault, restart pods)
✅ Centralized management
✅ Fine-grained access control
✅ Kubernetes-native authentication
✅ Production-ready
```

## Network Flow

```
External User ─(HTTP)─► Envoy LoadBalancer :80
                              │
                              ├─► /api/users ─► Varnish :6081
                              │                     │
                              │                     └─► user-management :8080
                              │                             │
                              │                             ├─► Dragonfly :6379
                              │                             ├─► Redpanda :9092
                              │                             ├─► ScyllaDB :9042
                              │                             └─► Vault :8200 (secrets)
                              │
                              └─► /health ─► Direct to backends

Developer ─(HTTP)─► Vault UI LoadBalancer :8200
                       │
                       └─► Vault Web Interface
                             - View secrets
                             - Manage policies
                             - Audit logs
                             - Unseal vault
```

## Security Layers

```
┌───────────────────────────────────────────────────────────────┐
│  Layer 1: Kubernetes RBAC                                     │
│  - ServiceAccount: vault-auth                                 │
│  - ClusterRole: vault-token-creator                           │
│  - ClusterRole: system:auth-delegator                         │
└───────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────────┐
│  Layer 2: Vault Authentication                                │
│  - Kubernetes auth method                                     │
│  - Token validation via K8s API                               │
│  - Role binding (adplatform → vault-auth SA)                  │
└───────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────────┐
│  Layer 3: Vault Authorization                                 │
│  - Policy: adplatform-policy                                  │
│  - Read access: secret/data/adplatform/*                      │
│  - No write, delete, or admin permissions                     │
└───────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────────┐
│  Layer 4: Data Encryption                                     │
│  - At rest: PersistentVolume encryption                       │
│  - In transit: HTTPS (recommended for production)             │
│  - In Vault: Encrypted with master key                        │
└───────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────────┐
│  Layer 5: Audit Logging (production)                          │
│  - All access logged                                          │
│  - Tamper-proof audit trail                                   │
│  - Integration with SIEM systems                              │
└───────────────────────────────────────────────────────────────┘
```

---

**Key Takeaway**: Vault provides defense-in-depth with multiple security layers, automated secret management, and production-ready infrastructure for managing sensitive credentials across all your services.
