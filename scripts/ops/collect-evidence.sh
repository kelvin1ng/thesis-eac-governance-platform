#!/usr/bin/env bash
set -euo pipefail

# Collect cluster and policy evidence into docs/evidence/<timestamp>.

REPO_ROOT="$(git rev-parse --show-toplevel)"
ENV_FILE="$REPO_ROOT/environments/dev/env.sh"
if [ -f "$ENV_FILE" ]; then
  . "$ENV_FILE"
else
  echo "Missing environment file: $ENV_FILE"
  exit 1
fi

GREEN='\033[0;32m'
NC='\033[0m'

cd "$REPO_ROOT"

EVIDENCE_DIR="${1:-}"
if [[ -z "$EVIDENCE_DIR" ]]; then
  TS=$(date +%Y%m%d-%H%M%S)
  EVIDENCE_DIR="docs/evidence/$TS"
fi
mkdir -p "$EVIDENCE_DIR"

echo "========================================"
echo "Collecting evidence -> $EVIDENCE_DIR"
echo "========================================"

kubectl get nodes -o wide &>"$EVIDENCE_DIR/nodes.txt" || true
kubectl get pods -A &>"$EVIDENCE_DIR/pods.txt" || true
kubectl get applications -n argocd &>"$EVIDENCE_DIR/argocd-apps.txt" 2>/dev/null || true
kubectl get constrainttemplates &>"$EVIDENCE_DIR/constrainttemplates.txt" 2>/dev/null || true
kubectl get constraints -A &>"$EVIDENCE_DIR/constraints.txt" 2>/dev/null || true
kubectl get svc -n monitoring &>"$EVIDENCE_DIR/monitoring-svc.txt" 2>/dev/null || true
kubectl get events -A --sort-by=.metadata.creationTimestamp &>"$EVIDENCE_DIR/events.txt" 2>/dev/null || true

# Optional: copy latest threat test log
if compgen -G "threat-tests-*.log" &>/dev/null; then
  LATEST=$(ls -t threat-tests-*.log 2>/dev/null | head -1)
  [[ -n "$LATEST" ]] && cp "$LATEST" "$EVIDENCE_DIR/" || true
fi

echo -e "${GREEN}Evidence written to $EVIDENCE_DIR${NC}"
ls -la "$EVIDENCE_DIR"
