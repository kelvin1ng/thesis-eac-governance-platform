#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
ENV_FILE="$REPO_ROOT/environments/dev/env.sh"
if [ -f "$ENV_FILE" ]; then
  . "$ENV_FILE"
else
  echo "Missing environment file: $ENV_FILE"
  exit 1
fi

echo "=== Phase 2 — Kubeconfig and cluster sanity ==="

aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" --profile "$AWS_PROFILE"

kubectl cluster-info
kubectl get nodes -o wide
kubectl get ns

# If no Ready nodes, run diagnostics
READY=$(kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | tr ' ' '\n' | grep -c True || echo 0)
if [[ "${READY:-0}" -eq 0 ]]; then
  echo "WARNING: No nodes in Ready state. Running diagnostics:"
  kubectl get nodes
  kubectl describe nodes
  kubectl get pods -A
  echo "Wait for nodes to become Ready, then re-run this script or proceed to Phase 3."
fi

echo ""
echo "Phase 2 complete. Next: run 03-phase3-core-addons.sh"
