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

echo "=== Phase 7 — Full verification ==="

cd "$REPO_ROOT"

echo "--- Cluster discovery ---"
kubectl get svc -n monitoring
kubectl get pods -n gatekeeper-system
kubectl get pods -n argocd
kubectl get pods -n monitoring
kubectl get applications -n argocd 2>/dev/null || true

echo ""
echo "--- PromQL queries (run manually in Prometheus at http://localhost:9090/graph) ---"
echo "  gatekeeper_validation_request_count_total{admission_status=\"deny\"}"
echo "  gatekeeper_validation_request_count{admission_status=\"deny\"}"
echo "  argocd_app_info"
echo "  argocd_app_info{sync_status=\"OutOfSync\"}"
echo "  count(argocd_app_info{sync_status=\"OutOfSync\"})"
echo "  kube_pod_status_ready{namespace=\"firewall\", condition=\"true\"}"
echo "  count(kube_pod_status_ready{namespace=\"firewall\", condition=\"true\"} == 1)"

echo ""
echo "--- Grafana dashboards to import (upload JSON from repo) ---"
echo "  monitoring/grafana/dashboards/argocd-sync.json"
echo "  monitoring/grafana/dashboards/gatekeeper-audit.json"

echo ""
echo "--- Port-forward examples (replace SVC_NAME with actual service from 'kubectl get svc -n monitoring') ---"
echo "  kubectl port-forward svc/SVC_NAME_FOR_GRAFANA -n monitoring 3000:80"
echo "  kubectl port-forward svc/SVC_NAME_FOR_PROMETHEUS -n monitoring 9090:9090"

echo ""
echo "Phase 7 complete. Next: run 08-phase8-threat-tests.sh"
