#!/usr/bin/env bash
# Validate deployment health

set -euo pipefail

ENV="${1:-staging}"
KUBECONFIG="$HOME/.kube/${ENV}-config.yaml"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "✅ Validating $ENV deployment..."

export KUBECONFIG

# Check cluster health
log "Checking cluster health..."
kubectl cluster-info

# Check all pods
log "Checking pod status..."
kubectl get pods -A | grep -v Running | grep -v Completed || log "All pods running!"

# Check services
log "Checking services..."
kubectl get svc -A

# Check specific components
log "Checking ScyllaDB..."
kubectl get pods -n scylla -l app=scylla

log "Checking Redpanda..."
kubectl get pods -n streaming -l app=redpanda

log "Checking ClickHouse..."
kubectl get pods -n analytics -l app=clickhouse

log "Checking DragonflyDB..."
kubectl get pods -n cache -l app=dragonfly

log "✅ Validation complete!"
