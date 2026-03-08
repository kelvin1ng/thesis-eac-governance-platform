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

echo "=== Phase 5 — Argo CD applications ==="

cd "$REPO_ROOT"

echo "--- Current repoURL in argocd manifests ---"
grep -R "repoURL:" argocd/ 2>/dev/null || true
echo "Verify repoURL only if your actual GitHub repo differs from the default expected repo."

echo "--- Applying Argo CD project and applications ---"
kubectl apply -f argocd/project-thesis.yaml
kubectl apply -f argocd/application-firewall.yaml
kubectl apply -f argocd/application-policies.yaml
kubectl apply -f argocd/rbac.yaml

echo "--- Verification ---"
kubectl get appprojects -n argocd
kubectl get applications -n argocd
kubectl get ns firewall 2>/dev/null || true
kubectl get deployment -n firewall 2>/dev/null || true

# On failure, print diagnostics (script continues; apply already succeeded or failed above)
if ! kubectl get application firewall -n argocd &>/dev/null; then
  echo "Application firewall not found or not synced. Diagnostics:"
  kubectl get appproject thesis -n argocd -o yaml 2>/dev/null || true
  kubectl describe application firewall -n argocd 2>/dev/null || true
fi

echo ""
echo "Phase 5 complete. Next: run 06-phase6-monitoring.sh"
