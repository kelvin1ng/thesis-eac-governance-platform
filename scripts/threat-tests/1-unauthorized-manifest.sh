#!/usr/bin/env bash
# Table 3 Threat 1: Unauthorized manifest change within the GitOps repository
# CHAPTER3_REFERENCE.md §3.6. Preventive: protected branches, PR review, required status checks.
# Detective: audit logs, Argo CD drift alerts. Corrective: Argo CD auto-sync revert.
# This script verifies preventive (docs/config) and detective (Argo CD sync status) controls.

set -euo pipefail
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_ROOT"

echo "[threat-1] Unauthorized manifest change — validating Table 3 controls"

# Preventive: branch protection and required status checks (documented)
if [[ -f .github/BRANCH-PROTECTION.md ]]; then
  echo "  [OK] Preventive: .github/BRANCH-PROTECTION.md exists (protected branches, required status checks)"
else
  echo "  [WARN] .github/BRANCH-PROTECTION.md not found; branch protection should be documented"
fi
if [[ -f .github/workflows/pr-checks.yaml ]]; then
  echo "  [OK] Preventive: PR workflow pr-checks.yaml (required status checks for Path A)"
else
  echo "  [FAIL] .github/workflows/pr-checks.yaml not found"
  exit 1
fi

# Detective: Argo CD drift visibility (sync status queryable)
if command -v kubectl &>/dev/null && kubectl get ns argocd &>/dev/null; then
  if kubectl get application -n argocd -o name &>/dev/null; then
    OUT_OF_SYNC=$(kubectl get application -n argocd -o jsonpath='{.items[*].status.sync.status}' 2>/dev/null | tr ' ' '\n' | grep -c OutOfSync || true)
    echo "  [OK] Detective: Argo CD applications visible; sync status queryable (OutOfSync count: ${OUT_OF_SYNC:-0})"
  else
    echo "  [SKIP] Detective: Argo CD not populated; run Argo CD and sync apps to validate drift alerts"
  fi
else
  echo "  [SKIP] Detective: kubectl/argocd namespace not available; deploy cluster and Argo CD to validate drift alerts"
fi

echo "[threat-1] Done. Corrective: Argo CD auto-sync (selfHeal) reverts unauthorized commits — see argocd/application-*.yaml syncPolicy."
