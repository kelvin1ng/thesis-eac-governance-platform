#!/usr/bin/env bash
set -euo pipefail

# EKS cluster health validation (uses environments/dev/env.sh).

REPO_ROOT="$(git rev-parse --show-toplevel)"
ENV_FILE="$REPO_ROOT/environments/dev/env.sh"
if [ -f "$ENV_FILE" ]; then
  . "$ENV_FILE"
else
  echo "Missing environment file: $ENV_FILE"
  exit 1
fi

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "========================================"
echo "EKS HEALTH CHECK"
echo "========================================"

# Cluster reachable
if ! aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" &>/dev/null; then
  echo -e "Cluster reachable: ${RED}FAIL${NC}"
  echo "Run: aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --profile $AWS_PROFILE"
  exit 1
fi
echo -e "Cluster reachable: ${GREEN}OK${NC}"

kubectl cluster-info &>/dev/null || { echo -e "kubectl cluster-info: ${RED}FAIL${NC}"; exit 1; }

echo ""
echo "--- Nodes ---"
kubectl get nodes -o wide
echo ""

NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready " | grep -c . || true)
if [[ "${NOT_READY:-0}" -gt 0 ]]; then
  echo -e "Nodes ready: ${RED}FAIL${NC} ($NOT_READY node(s) not Ready)"
  exit 1
fi
echo -e "Nodes ready: ${GREEN}OK${NC}"

echo ""
echo "--- Pods (all namespaces) ---"
kubectl get pods -A 2>/dev/null | tail -n 50
echo ""

# kube-system CrashLoopBackOff
if kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -q CrashLoopBackOff; then
  echo -e "kube-system pods: ${RED}FAIL${NC} (CrashLoopBackOff detected)"
  exit 1
fi

# CoreDNS
if ! kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -E 'coredns|dns' | grep -q Running; then
  echo -e "CoreDNS: ${RED}FAIL${NC} (not running)"
  exit 1
fi
echo -e "CoreDNS: ${GREEN}OK${NC}"

# Argo CD server
if ! kubectl get pods -n argocd --no-headers 2>/dev/null | grep -q argocd-server; then
  echo -e "ArgoCD: ${RED}FAIL${NC} (argocd-server pod missing)"
  exit 1
fi
ARGOCD_RUNNING=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers 2>/dev/null | grep -c Running || true)
if [[ "${ARGOCD_RUNNING:-0}" -eq 0 ]]; then
  echo -e "ArgoCD: ${YELLOW}WARNING${NC} (argocd-server not Running)"
else
  echo -e "ArgoCD: ${GREEN}OK${NC}"
fi

# Gatekeeper
if ! kubectl get pods -n gatekeeper-system --no-headers 2>/dev/null | grep -q gatekeeper-controller-manager; then
  echo -e "Gatekeeper: ${RED}FAIL${NC} (gatekeeper-controller-manager missing)"
  exit 1
fi
GK_RUNNING=$(kubectl get pods -n gatekeeper-system -l control-plane=controller-manager --no-headers 2>/dev/null | grep -c Running || true)
if [[ "${GK_RUNNING:-0}" -eq 0 ]]; then
  echo -e "Gatekeeper: ${YELLOW}WARNING${NC} (controller not Running)"
else
  echo -e "Gatekeeper: ${GREEN}OK${NC}"
fi

echo ""
echo "--- Recent events ---"
kubectl get events -A --sort-by=.metadata.creationTimestamp 2>/dev/null | tail -n 25
echo ""
echo "========================================"
echo -e "${GREEN}Cluster status: HEALTHY${NC}"
echo "========================================"
