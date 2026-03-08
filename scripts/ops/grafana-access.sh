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

# Find Grafana service in monitoring namespace and start port-forward.

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "========================================"
echo "Grafana access (namespace: monitoring)"
echo "========================================"

if ! kubectl get ns monitoring &>/dev/null; then
  echo -e "${RED}Namespace 'monitoring' not found. Install kube-prometheus-stack (phase6) first.${NC}"
  exit 1
fi

GRAFANA_SVC=$(kubectl get svc -n monitoring --no-headers 2>/dev/null | grep -i grafana | head -1 | awk '{print $1}')
if [[ -z "${GRAFANA_SVC:-}" ]]; then
  echo -e "${RED}No Grafana service found in namespace monitoring.${NC}"
  kubectl get svc -n monitoring
  exit 1
fi

echo -e "Grafana service: ${GREEN}$GRAFANA_SVC${NC}"
echo "Starting port-forward (bind to localhost:3000). Press Ctrl+C to stop."
echo ""
echo -e "${GREEN}Grafana available at:${NC}"
echo "  http://localhost:3000"
echo ""
echo "Login: admin / admin"
echo ""

if command -v xdg-open &>/dev/null; then
  (sleep 2 && xdg-open "http://localhost:3000" 2>/dev/null) &
fi

kubectl port-forward "svc/$GRAFANA_SVC" -n monitoring 3000:80
