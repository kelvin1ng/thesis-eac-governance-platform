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

echo "=== Phase 6 — Monitoring / Observability ==="

cd "$REPO_ROOT"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install "$MONITORING_RELEASE" prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin \
  --wait --timeout 300s

kubectl get pods -n monitoring

kubectl apply -f monitoring/prometheus/alerts.yaml
kubectl apply -f monitoring/prometheus/servicemonitor-gatekeeper.yaml
kubectl apply -f monitoring/prometheus/gatekeeper-podmonitor.yaml

kubectl label prometheusrule thesis-eac-alerts -n monitoring "release=$MONITORING_RELEASE" --overwrite
kubectl label servicemonitor gatekeeper -n gatekeeper-system "release=$MONITORING_RELEASE" --overwrite
kubectl label podmonitor gatekeeper-controller-manager -n monitoring "release=$MONITORING_RELEASE" --overwrite

echo "--- Verification ---"
kubectl get pods -n monitoring
kubectl get prometheusrules -n monitoring
kubectl get servicemonitors -A
kubectl get podmonitors -A
kubectl get svc -n monitoring

echo "--- Service discovery (use these for port-forward) ---"
kubectl get svc -n monitoring | grep -i grafana || true
kubectl get svc -n monitoring | grep -i prometheus || true

echo ""
echo "Port-forward (run in separate terminals; replace SVC_NAME with output above):"
echo "  Grafana:    kubectl port-forward svc/SVC_NAME_FOR_GRAFANA -n monitoring 3000:80"
echo "  Prometheus: kubectl port-forward svc/SVC_NAME_FOR_PROMETHEUS -n monitoring 9090:9090"
echo "Do not automate browser opening; use http://localhost:3000 and http://localhost:9090 manually."
echo ""
echo "Phase 6 complete. Next: run 07-phase7-verification.sh"
