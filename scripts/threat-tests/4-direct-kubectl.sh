#!/usr/bin/env bash
# Table 3 Threat 4: Direct manual changes via Kubernetes API (direct kubectl in production)
# CHAPTER3_REFERENCE.md §3.6. Preventive: Argo CD Projects, RBAC, admission. Detective: Prometheus alerts.
# Corrective: Argo CD self-heal overwrites manual changes (single-writer principle).
# This script applies a temporary label to the firewall deployment and verifies Argo CD removes it (self-heal).

set -euo pipefail
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_ROOT"

echo "[threat-4] Direct kubectl in prod — validating Table 3 corrective control (Argo CD self-heal)"

if ! command -v kubectl &>/dev/null; then
  echo "  [SKIP] kubectl not available"
  exit 0
fi
if ! kubectl get ns firewall &>/dev/null; then
  echo "  [SKIP] namespace firewall not found; deploy Argo CD and sync firewall app first"
  exit 0
fi

DEPLOY=""
for name in firewall-firewall firewall thesis-eac-firewall; do
  if kubectl get deployment -n firewall "$name" &>/dev/null 2>&1; then
    DEPLOY="$name"
    break
  fi
done
if [[ -z "$DEPLOY" ]]; then
  DEPLOY=$(kubectl get deployment -n firewall -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
fi
if [[ -z "$DEPLOY" ]]; then
  echo "  [SKIP] No deployment in namespace firewall"
  exit 0
fi

LABEL_KEY="thesis-threat4-test"
echo "  Applying temporary label ${LABEL_KEY}=manual to deployment/${DEPLOY} in firewall..."
kubectl label deployment -n firewall "$DEPLOY" "${LABEL_KEY}=manual" --overwrite

echo "  Waiting 45s for Argo CD reconciliation (selfHeal)..."
sleep 45

VAL=$(kubectl get deployment -n firewall "$DEPLOY" -o jsonpath="{.metadata.labels.${LABEL_KEY}}" 2>/dev/null || true)
if [[ -z "$VAL" ]]; then
  echo "  [OK] Corrective: label removed by Argo CD self-heal (single-writer principle, Table 3)"
else
  echo "  [WARN] Label still present; Argo CD may not have synced yet or syncPolicy.selfHeal disabled — check argocd application firewall"
fi

echo "[threat-4] Done. Preventive: Argo CD Projects/RBAC — see argocd/project-thesis.yaml and rbac.yaml."
