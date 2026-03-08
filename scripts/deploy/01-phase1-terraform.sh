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

echo "=== Phase 1 — Terraform (EKS rebuild) ==="

cd "$REPO_ROOT"

# Create backend (S3 bucket; lock table optional with use_lockfile)
echo "--- Creating Terraform backend (thesis-eac-tfstate, $AWS_REGION) ---"
./scripts/create-terraform-backend.sh thesis-eac-tfstate "$AWS_REGION"

# Ensure infra/backend.hcl exists
if [[ ! -f infra/backend.hcl ]]; then
  if [[ -f infra/backend.hcl.example ]]; then
    cp infra/backend.hcl.example infra/backend.hcl
    echo "Copied infra/backend.hcl.example to infra/backend.hcl"
  else
    echo "ERROR: infra/backend.hcl missing and infra/backend.hcl.example not found. Create backend.hcl with bucket, key, region, use_lockfile, profile."
    exit 1
  fi
fi

echo "--- backend.hcl ---"
cat infra/backend.hcl

cd "$REPO_ROOT/infra"

echo "--- terraform init -reconfigure -backend-config=backend.hcl ---"
terraform init -reconfigure -backend-config=backend.hcl

TFVARS="$REPO_ROOT/environments/dev/terraform.tfvars"
echo "--- terraform plan ---"
terraform plan -var-file="$TFVARS" || {
  echo "Plan failed. Diagnostics:"
  terraform version
  terraform providers
  exit 1
}

echo "--- terraform apply (auto-approve) ---"
terraform apply -auto-approve -var-file="$TFVARS" || {
  echo "Apply failed. Next steps: check infra/README.md for backend and EKS access entry. Diagnostics:"
  terraform version
  terraform providers
  exit 1
}

echo ""
echo "Phase 1 complete. Next: run 02-phase2-kubeconfig.sh"
