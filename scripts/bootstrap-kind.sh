#!/usr/bin/env bash
# Bootstrap: Kind cluster + Tekton, Argo CD, Gatekeeper, Prometheus stack (local first)
# CHAPTER3_REFERENCE.md: §3.2 (Four Layers, Table 1), §3.3 (Platform-Centric), §3.1 Observability/Evidence Plane
# Step 1 of PROJECT_PLAN.md implementation order.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-thesis-eac}"

echo "[bootstrap] Using cluster name: $CLUSTER_NAME"

# --- Kind cluster (3.2 Layer 4 execution plane host) ---
KIND_CONFIG="$REPO_ROOT/.kind-config.yaml"
cat > "$KIND_CONFIG" << 'KINDEOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
KINDEOF
if kind get kubeconfig --name "$CLUSTER_NAME" &>/dev/null; then
  echo "[bootstrap] Kind cluster '$CLUSTER_NAME' already exists; skipping create."
else
  echo "[bootstrap] Creating Kind cluster '$CLUSTER_NAME'..."
  kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"
fi
rm -f "$KIND_CONFIG"

export KUBECONFIG="$(kind get kubeconfig --name "$CLUSTER_NAME" --internal 2>/dev/null || kind get kubeconfig --name "$CLUSTER_NAME")"
kubectl cluster-info --context "kind-$CLUSTER_NAME" || true

# --- Tekton Pipelines (Table 1: Orchestration and Delivery, Execution Plane) ---
echo "[bootstrap] Installing Tekton Pipelines..."
# Table 1: Tekton Pipelines - Execution Plane
kubectl apply -f "https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml"
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/part-of=tekton-pipelines -n tekton-pipelines --timeout=300s 2>/dev/null || true

# --- Argo CD (Table 1: Orchestration and Delivery, Control Plane; §3.3 Platform-Centric) ---
echo "[bootstrap] Installing Argo CD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s 2>/dev/null || true

# --- Gatekeeper (Table 1: Policy Enforcement, Control Plane; §3.2.2 Layer 2) ---
echo "[bootstrap] Installing Gatekeeper..."
kubectl apply -f "https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.15/deploy/gatekeeper.yaml"
kubectl wait --for=condition=Available deployment/gatekeeper-controller-manager -n gatekeeper-system --timeout=300s 2>/dev/null || true

# --- Prometheus stack (Table 1: Evidence Plane; §3.1 Observability) ---
echo "[bootstrap] Installing Prometheus stack (kube-prometheus-stack)..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin \
  --wait --timeout 300s 2>/dev/null || true

echo "[bootstrap] Step 1 complete. Cluster '$CLUSTER_NAME' has Tekton, Argo CD, Gatekeeper, and Prometheus stack."
echo "  kubectl config use-context kind-$CLUSTER_NAME"
echo "  Argo CD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Grafana:   kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
