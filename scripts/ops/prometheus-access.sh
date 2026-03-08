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

# Find Prometheus service in monitoring namespace and start port-forward.

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "========================================"
echo "Prometheus access (namespace: monitoring)"
echo "========================================"

if ! kubectl get ns monitoring &>/dev/null; then
  echo -e "${RED}Namespace 'monitoring' not found. Install kube-prometheus-stack (phase6) first.${NC}"
  exit 1
fi

# Prefer the main Prometheus server (often ends with -prometheus, not -alertmanager or -operator)
PROM_SVC=$(kubectl get svc -n monitoring --no-headers 2>/dev/null | grep -i prometheus | grep -v alertmanager | grep -v operator | head -1 | awk '{print $1}')
if [[ -z "${PROM_SVC:-}" ]]; then
  PROM_SVC=$(kubectl get svc -n monitoring --no-headers 2>/dev/null | grep -i prometheus | head -1 | awk '{print $1}')
fi
if [[ -z "${PROM_SVC:-}" ]]; then
  echo -e "${RED}No Prometheus service found in namespace monitoring.${NC}"
  kubectl get svc -n monitoring
  exit 1
fi

echo -e "Prometheus service: ${GREEN}$PROM_SVC${NC}"
echo "Starting port-forward (bind to localhost:9090). Press Ctrl+C to stop."
echo ""
echo -e "${GREEN}Prometheus UI:${NC}"
echo "  http://localhost:9090"
echo ""

kubectl port-forward "svc/$PROM_SVC" -n monitoring 9090:9090
