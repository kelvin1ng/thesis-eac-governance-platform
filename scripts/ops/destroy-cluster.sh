#!/usr/bin/env bash
set -euo pipefail

# Safely destroy EKS and related infrastructure via Terraform (uses environments/dev).

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
echo "DESTROY CLUSTER ($CLUSTER_NAME)"
echo "========================================"
echo ""
echo -e "${RED}This will run 'terraform destroy' in infra/ and remove the EKS cluster and related resources.${NC}"
echo "Type DESTROY to continue (anything else aborts):"
read -r CONFIRM
if [[ "$CONFIRM" != "DESTROY" ]]; then
  echo "Aborted."
  exit 1
fi

TFVARS="$REPO_ROOT/environments/dev/terraform.tfvars"
cd "$REPO_ROOT/infra"

echo "Initializing Terraform backend (infra/)..."
terraform init -reconfigure -backend-config=backend.hcl

terraform destroy -auto-approve -var-file="$TFVARS"

echo ""
echo "Removing kubeconfig context..."
kubectl config delete-context "arn:aws:eks:${AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):cluster/${CLUSTER_NAME}" 2>/dev/null || true

echo ""
echo "Verifying clusters in account..."
aws eks list-clusters --region "$AWS_REGION" --profile "$AWS_PROFILE" --output text

echo ""
echo "========================================"
echo -e "${GREEN}Destroy complete.${NC}"
echo "========================================"
