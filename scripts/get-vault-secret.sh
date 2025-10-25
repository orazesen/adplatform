#!/bin/bash
set -e

echo "Retrieving secret from Vault: $1"

VAULT_POD=$(kubectl get pods -n adplatform -l app=vault -o jsonpath='{.items[0].metadata.name}')
SECRET_PATH=$1
FIELD=${2:-""}

if [ -z "$SECRET_PATH" ]; then
    echo "Usage: $0 <secret-path> [field]"
    echo "Example: $0 adplatform/dragonfly password"
    exit 1
fi

if [ -z "$FIELD" ]; then
    kubectl exec -n adplatform $VAULT_POD -- vault kv get -format=json secret/$SECRET_PATH | jq -r '.data.data'
else
    kubectl exec -n adplatform $VAULT_POD -- vault kv get -format=json secret/$SECRET_PATH | jq -r ".data.data.$FIELD"
fi
