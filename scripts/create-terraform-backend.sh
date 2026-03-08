#!/usr/bin/env bash
# Create S3 bucket + DynamoDB table for Terraform remote backend
# CHAPTER3_REFERENCE.md §3.2.1 Layer 1, Table 1: state storage and locking [5]
# Use: AWS_PROFILE=thesis ./scripts/create-terraform-backend.sh [bucket] [region]

set -euo pipefail
BUCKET="${1:-thesis-eac-tfstate}"
REGION="${2:-us-east-1}"
TABLE="${3:-thesis-eac-tfstate-lock}"
PROFILE="${AWS_PROFILE:-thesis}"

echo "[backend] Creating S3 bucket: $BUCKET (region: $REGION, profile: $PROFILE)"
if [ "$REGION" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" --profile "$PROFILE" 2>/dev/null || true
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION" --profile "$PROFILE" 2>/dev/null || true
fi

aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled --profile "$PROFILE"
aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' --profile "$PROFILE"

echo "[backend] Creating DynamoDB table: $TABLE"
aws dynamodb create-table --table-name "$TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION" --profile "$PROFILE" 2>/dev/null || true

echo "[backend] Done. Create infra/backend.hcl with: bucket=\"$BUCKET\", region=\"$REGION\", dynamodb_table=\"$TABLE\", profile=\"$PROFILE\""
