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

# Warn about potentially expensive AWS resources (EKS, EC2, NAT, EIP, ALB).

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "========================================"
echo "AWS COST GUARDRAIL CHECK"
echo "========================================"

NAT_COUNT=0
EC2_COUNT=0
INSTANCE_TYPES=""
EIP_COUNT=0
ALB_COUNT=0

# EKS node groups
if aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" &>/dev/null; then
  NODEGROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query 'nodegroups[]' --output text)
  echo "EKS node groups: ${NODEGROUPS:-none}"
fi

# EC2 instances (running)
OUT=$(aws ec2 describe-instances --region "$AWS_REGION" --profile "$AWS_PROFILE" \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType]' --output text 2>/dev/null || true)
[[ -n "$OUT" ]] && EC2_COUNT=$(echo "$OUT" | wc -l) || EC2_COUNT=0
if [[ "$EC2_COUNT" -gt 0 ]]; then
  INSTANCE_TYPES=$(echo "$OUT" | awk '{print $2}' | sort -u | tr '\n' ' ')
fi

# NAT gateways
NAT_COUNT=$(aws ec2 describe-nat-gateways --region "$AWS_REGION" --profile "$AWS_PROFILE" \
  --filter "Name=state,Values=available,pending" --query 'NatGateways[].NatGatewayId' --output text 2>/dev/null | wc -w)

# Elastic IPs
EIP_COUNT=$(aws ec2 describe-addresses --region "$AWS_REGION" --profile "$AWS_PROFILE" \
  --query 'Addresses[].AllocationId' --output text 2>/dev/null | wc -w)

# Load balancers (v2)
ALB_COUNT=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --profile "$AWS_PROFILE" \
  --query 'LoadBalancers[].LoadBalancerArn' --output text 2>/dev/null | wc -w)

echo ""
echo "NAT Gateways: $NAT_COUNT"
if [[ "$NAT_COUNT" -gt 0 ]]; then
  echo -e "${YELLOW}NAT Gateway running — approx \$30/month base cost.${NC}"
fi

echo ""
echo "EC2 nodes running: $EC2_COUNT"
if [[ -n "$INSTANCE_TYPES" ]]; then
  echo "Instance type(s): $INSTANCE_TYPES"
fi
if [[ "$EC2_COUNT" -gt 2 ]]; then
  echo -e "${YELLOW}More than 2 nodes — review compute cost.${NC}"
fi

echo ""
echo "Elastic IPs: $EIP_COUNT"

echo ""
echo "Load balancers (ALB/NLB): $ALB_COUNT"

echo ""
# Cost risk level
if [[ "$NAT_COUNT" -gt 0 ]] && [[ "$EC2_COUNT" -gt 2 ]]; then
  echo -e "Cost risk level: ${YELLOW}MEDIUM${NC}"
elif [[ "$NAT_COUNT" -gt 0 ]] || [[ "$EC2_COUNT" -gt 2 ]]; then
  echo -e "Cost risk level: ${YELLOW}LOW${NC}"
else
  echo -e "Cost risk level: ${GREEN}LOW${NC}"
fi
echo "========================================"
