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

echo "=== Phase 3 — Core add-ons (Gatekeeper, Argo CD) ==="

cd "$REPO_ROOT"

kubectl create namespace gatekeeper-system --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.15/deploy/gatekeeper.yaml"
kubectl wait --for=condition=Available deployment/gatekeeper-controller-manager -n gatekeeper-system --timeout=300s

kubectl set resources deployment/gatekeeper-controller-manager -n gatekeeper-system \
  --limits=memory=384Mi --requests=memory=128Mi
kubectl rollout status deployment/gatekeeper-controller-manager -n gatekeeper-system
kubectl get pods -n gatekeeper-system

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s
kubectl get pods -n argocd

