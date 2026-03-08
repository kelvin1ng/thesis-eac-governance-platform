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

echo "=== Phase 4 — Gatekeeper policies ==="

cd "$REPO_ROOT"

echo "--- Waiting for Gatekeeper CRD ---"
kubectl wait --for=condition=Established crd/constrainttemplates.templates.gatekeeper.sh --timeout=120s

echo "--- Applying policies ---"
if ! ./scripts/apply-policies.sh; then
  echo "apply-policies.sh failed. Diagnostics:"
  kubectl get pods -n gatekeeper-system
  kubectl logs -n gatekeeper-system -l control-plane=controller-manager -c manager --tail=50 2>/dev/null || true
  kubectl get constrainttemplates -o wide 2>/dev/null || true
  kubectl describe constrainttemplates 2>/dev/null || true
  kubectl get constraints -A 2>/dev/null || true
  kubectl describe constraints -A 2>/dev/null || true
  exit 1
fi

echo "--- Verification ---"
kubectl get constrainttemplates
kubectl get constraints -A
kubectl get validatingwebhookconfiguration | grep gatekeeper

echo ""
echo "Phase 4 complete. Next: run 05-phase5-argocd-apps.sh"
