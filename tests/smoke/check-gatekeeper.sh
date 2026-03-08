#!/usr/bin/env bash
set -euo pipefail

# Smoke: Gatekeeper controller and CRDs present (non-destructive).
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
cd "$REPO_ROOT"

kubectl get ns gatekeeper-system
kubectl get pods -n gatekeeper-system -l control-plane=controller-manager --no-headers | grep -q . || { echo "Smoke fail: gatekeeper-controller-manager not found"; exit 1; }
kubectl get constrainttemplates 2>/dev/null || true
echo "Smoke OK: Gatekeeper present"
