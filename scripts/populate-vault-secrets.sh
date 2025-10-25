#!/bin/bash
set -e

echo "================================================"
echo "Populating Vault with Ad Platform Secrets"
echo "================================================"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first."
    exit 1
fi

# Get Vault pod and token
VAULT_POD=$(kubectl get pods -n adplatform -l app=vault -o jsonpath='{.items[0].metadata.name}')
VAULT_TOKEN=$(kubectl get secret vault-token -n adplatform -o jsonpath='{.data.token}' | base64 -d)

if [ -z "$VAULT_POD" ]; then
    echo "Error: Vault pod not found. Run setup-vault.sh first."
    exit 1
fi

echo "Using Vault pod: $VAULT_POD"
echo ""

# Function to generate secure password
generate_password() {
    openssl rand -base64 32 | tr -d '=/+' | cut -c1-32
}

# Function to generate long secret
generate_secret() {
    openssl rand -base64 48 | tr -d '=/+' | cut -c1-48
}

echo "Generating secure credentials..."
DRAGONFLY_PASSWORD=$(generate_password)
REDPANDA_ADMIN_PASSWORD=$(generate_password)
REDPANDA_SASL_PASSWORD=$(generate_password)
SCYLLA_PASSWORD=$(generate_password)
USER_MANAGEMENT_SECRET=$(generate_secret)
JWT_SECRET=$(generate_secret)
VARNISH_SECRET=$(generate_password)

echo "✓ Credentials generated"
echo ""

# Store Dragonfly secrets
echo "1. Storing Dragonfly (Redis) secrets..."
kubectl exec -n adplatform $VAULT_POD -- vault kv put secret/adplatform/dragonfly \
    password="$DRAGONFLY_PASSWORD" \
    host="dragonfly" \
    port="6379" \
    connection_url="redis://:$DRAGONFLY_PASSWORD@dragonfly:6379/0" > /dev/null
echo "   ✓ Dragonfly secrets stored"

# Store Redpanda secrets
echo "2. Storing Redpanda (Kafka) secrets..."
kubectl exec -n adplatform $VAULT_POD -- vault kv put secret/adplatform/redpanda \
    admin_user="admin" \
    admin_password="$REDPANDA_ADMIN_PASSWORD" \
    sasl_username="adplatform_user" \
    sasl_password="$REDPANDA_SASL_PASSWORD" \
    brokers="redpanda:9092" \
    admin_api="redpanda:9644" > /dev/null
echo "   ✓ Redpanda secrets stored"

# Store ScyllaDB secrets
echo "3. Storing ScyllaDB (Cassandra) secrets..."
kubectl exec -n adplatform $VAULT_POD -- vault kv put secret/adplatform/scylla \
    username="cassandra" \
    password="$SCYLLA_PASSWORD" \
    keyspace="adplatform" \
    hosts="scylla-0.scylla,scylla-1.scylla,scylla-2.scylla" \
    port="9042" > /dev/null
echo "   ✓ ScyllaDB secrets stored"

# Store User Management secrets
echo "4. Storing User Management service secrets..."
kubectl exec -n adplatform $VAULT_POD -- vault kv put secret/adplatform/user-management \
    secret_key="$USER_MANAGEMENT_SECRET" \
    jwt_secret="$JWT_SECRET" \
    jwt_expiration_hours="24" \
    port="8080" > /dev/null
echo "   ✓ User Management secrets stored"

# Store Varnish secrets
echo "5. Storing Varnish secrets..."
kubectl exec -n adplatform $VAULT_POD -- vault kv put secret/adplatform/varnish \
    admin_secret="$VARNISH_SECRET" \
    port="6081" \
    admin_port="6082" > /dev/null
echo "   ✓ Varnish secrets stored"

# Store application configuration
echo "6. Storing application configuration..."
kubectl exec -n adplatform $VAULT_POD -- vault kv put secret/adplatform/config \
    app_env="development" \
    log_level="info" \
    rust_log="info" \
    metrics_port="9090" \
    tracing_enabled="true" \
    cors_allowed_origins="http://localhost:*,http://127.0.0.1:*" \
    api_rate_limit="1000" > /dev/null
echo "   ✓ Application configuration stored"

# Store Envoy configuration
echo "7. Storing Envoy configuration..."
kubectl exec -n adplatform $VAULT_POD -- vault kv put secret/adplatform/envoy \
    admin_port="9901" \
    listener_port="80" > /dev/null
echo "   ✓ Envoy configuration stored"

echo ""
echo "================================================"
echo "✅ All secrets populated successfully!"
echo "================================================"
echo ""
echo "To view secrets:"
echo "  vault kv get secret/adplatform/dragonfly"
echo "  vault kv get secret/adplatform/redpanda"
echo "  vault kv get secret/adplatform/scylla"
echo "  vault kv get secret/adplatform/user-management"
echo ""
echo "Or via kubectl:"
echo "  kubectl exec -n adplatform $VAULT_POD -- vault kv get secret/adplatform/dragonfly"
echo ""
