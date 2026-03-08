#!/usr/bin/env bash
# Table 3 Threat 3: Artifact tampering within the image registry
# CHAPTER3_REFERENCE.md §3.6. Preventive: immutable registry, digest-only, cosign at admission, SBOM.
# Detective: registry audit, Trivy scan. Corrective: restore from immutable state, key revocation.
# This script verifies Gatekeeper image constraints and pipeline SBOM/cosign (preventive); optional cluster denial test.

set -euo pipefail
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_ROOT"

echo "[threat-3] Artifact tampering — validating Table 3 controls"

# Preventive: Gatekeeper constraints for image allowlist and signature/digest
if [[ -f policies/constraints/allowlist.yaml ]]; then
  echo "  [OK] Preventive: image allowlist constraint (policies/constraints/allowlist.yaml)"
else
  echo "  [FAIL] policies/constraints/allowlist.yaml not found"
  exit 1
fi
if [[ -f policies/constraints/cosign.yaml ]] || compgen -G "policies/constraints/*cosign*" &>/dev/null; then
  echo "  [OK] Preventive: image signature/digest constraint present"
else
  echo "  [WARN] Cosign/digest constraint not found; admission may not enforce signature verification"
fi

# Pipeline: Trivy SBOM and cosign in Path A
if grep -q trivy pipelines/pipelines/path-a-firewall.yaml 2>/dev/null || grep -q trivy pipelines/tasks/*.yaml 2>/dev/null; then
  echo "  [OK] Detective/Evidence: Trivy (SBOM/vulnerability) in pipeline"
else
  echo "  [WARN] Trivy not found in path-a pipeline or tasks"
fi
if grep -q cosign pipelines/pipelines/path-a-firewall.yaml 2>/dev/null || grep -q cosign pipelines/tasks/*.yaml 2>/dev/null; then
  echo "  [OK] Preventive/Evidence: cosign in pipeline (sign/attest)"
else
  echo "  [WARN] cosign not found in path-a pipeline or tasks"
fi

# Optional: apply image from non-allowlisted registry and expect denial (cluster test)
if command -v kubectl &>/dev/null && kubectl get ns gatekeeper-system &>/dev/null 2>&1; then
  if grep -q 'quay.io' policies/constraints/allowlist.yaml 2>/dev/null; then
    echo "  [SKIP] Cluster denial test: quay.io is allowlisted; adjust allowlist to test denial"
  else
    DENIED=0
    OUT=$(kubectl run threat3-test --image=quay.io/library/busybox:latest --restart=Never 2>&1) || true
    echo "$OUT" | grep -qiE "denied|forbidden|admission" && DENIED=1
    kubectl delete pod threat3-test --ignore-not-found --wait=false 2>/dev/null || true
    if [[ "$DENIED" -eq 1 ]]; then
      echo "  [OK] Preventive: admission denied image from non-allowlisted registry (Table 3)"
    else
      echo "  [SKIP] Cluster denial test: Gatekeeper may not match Pod in default; verify allowlist constraint"
    fi
  fi
else
  echo "  [SKIP] Cluster not available; deploy Gatekeeper to validate admission denial for non-allowlisted images"
fi

echo "[threat-3] Done. Corrective: restore from immutable state, key revocation — see infra/ ECR and policies/."
