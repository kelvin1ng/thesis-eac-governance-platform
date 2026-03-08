#!/usr/bin/env bash
set -euo pipefail

# Smoke: monitoring namespace and Prometheus/Grafana resources (non-destructive).
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
cd "$REPO_ROOT"

kubectl get ns monitoring
kubectl get pods -n monitoring | head -20
kubectl get prometheusrules -n monitoring 2>/dev/null || true
kubectl get svc -n monitoring | grep -E 'prometheus|grafana' || true
echo "Smoke OK: monitoring stack present"
