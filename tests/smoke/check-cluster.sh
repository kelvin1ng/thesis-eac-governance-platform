#!/usr/bin/env bash
set -euo pipefail

# Smoke: cluster reachable and nodes Ready (non-destructive).
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
cd "$REPO_ROOT"

kubectl cluster-info
kubectl get nodes -o wide
NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready " | grep -c . || true)
[[ "${NOT_READY:-0}" -eq 0 ]] || { echo "Smoke fail: one or more nodes not Ready"; exit 1; }
echo "Smoke OK: cluster reachable, nodes Ready"
