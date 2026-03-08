#!/usr/bin/env bash
set -euo pipefail

# Smoke: Argo CD namespace and server pod exist (non-destructive).
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
cd "$REPO_ROOT"

kubectl get ns argocd
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers | grep -q . || { echo "Smoke fail: argocd-server pod not found"; exit 1; }
kubectl get applications -n argocd 2>/dev/null || true
echo "Smoke OK: Argo CD present"
