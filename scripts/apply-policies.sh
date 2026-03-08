#!/usr/bin/env bash
# Apply Layer 2 Gatekeeper policies to cluster
# CHAPTER3_REFERENCE.md §3.2.2 Layer 2, Table 1
# Usage: ./scripts/apply-policies.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[policies] Applying ConstraintTemplates..."
kubectl apply -f "$REPO_ROOT/policies/templates/"

echo "[policies] Waiting for CRDs..."
kubectl wait --for=condition=Established crd/constrainttemplates.templates.gatekeeper.sh --timeout=120s 2>/dev/null || true
sleep 5

echo "[policies] Applying Constraints..."
kubectl apply -f "$REPO_ROOT/policies/constraints/"

echo "[policies] Done. Check status: kubectl get constrainttemplates, kubectl get constraints"
