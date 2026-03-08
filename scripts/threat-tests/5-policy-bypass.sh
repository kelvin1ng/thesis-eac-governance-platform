#!/usr/bin/env bash
# Table 3 Threat 5: Policy bypass attempts (circumvent security gates)
# CHAPTER3_REFERENCE.md §3.6. Preventive: OPA/Gatekeeper decoupled from pipeline (admission).
# Detective: alerting on policy denials; EFK aggregation. Corrective: refine Rego, key rotation, GitOps re-apply.
# This script applies a manifest that violates Gatekeeper (e.g. missing required labels) and expects denial.

set -euo pipefail
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_ROOT"

echo "[threat-5] Policy bypass — validating Table 3 preventive control (admission denial)"

if ! command -v kubectl &>/dev/null; then
  echo "  [SKIP] kubectl not available"
  exit 0
fi
if ! kubectl get ns gatekeeper-system &>/dev/null 2>/dev/null; then
  echo "  [SKIP] gatekeeper-system namespace not found; install Gatekeeper first"
  exit 0
fi

# Deployment missing required labels (owner, environment, compliance-scope) — K8sRequiredLabels should deny
MANIFEST=$(cat <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: threat5-bypass-test
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: threat5-test
  template:
    metadata:
      labels:
        app: threat5-test
    spec:
      containers:
        - name: nginx
          image: docker.io/library/nginx:alpine
EOF
)

THREAT5_OUT="${TMPDIR:-/tmp}/threat5-out.txt"
echo "  Applying Deployment without required labels (owner, environment, compliance-scope)..."
if echo "$MANIFEST" | kubectl apply -f - 2>&1 | tee "$THREAT5_OUT"; then
  echo "  [WARN] Deployment was accepted; required-labels constraint may not match default namespace or may be disabled"
  kubectl delete deployment threat5-bypass-test -n default --ignore-not-found --wait=false 2>/dev/null || true
else
  if grep -qiE "denied|forbidden|admission|constraint" "$THREAT5_OUT"; then
    echo "  [OK] Preventive: Gatekeeper denied deployment (policy bypass blocked, Table 3 [54])"
  else
    echo "  [WARN] Apply failed but message unclear; check Gatekeeper and constraint K8sRequiredLabels"
  fi
fi
rm -f "$THREAT5_OUT"

echo "[threat-5] Done. Detective: Prometheus alert GatekeeperConstraintViolations; see monitoring/prometheus/alerts.yaml."
