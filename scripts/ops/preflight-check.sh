#!/usr/bin/env bash
set -euo pipefail

# Preflight: git repo, path under /home, required binaries, AWS and optional kubectl access.

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
echo "Preflight check"
echo "========================================"

cd "$REPO_ROOT"
echo -e "Repo root: ${GREEN}$REPO_ROOT${NC}"

# Path under /home (WSL)
if [[ "$REPO_ROOT" == /mnt/* ]]; then
  echo -e "${RED}FAIL: Repo is under Windows mount ($REPO_ROOT). Use a path under /home in WSL.${NC}"
  exit 1
fi
if [[ "$REPO_ROOT" != /home/* ]]; then
  echo -e "${YELLOW}WARN: Repo not under /home. Prefer /home/... for WSL.${NC}"
fi

# Required binaries
MISSING=()
for cmd in aws terraform kubectl helm git; do
  command -v "$cmd" &>/dev/null || MISSING+=("$cmd")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo -e "${RED}FAIL: Missing required binaries: ${MISSING[*]}${NC}"
  exit 1
fi
echo -e "Required binaries: ${GREEN}OK${NC}"

# AWS
if ! aws sts get-caller-identity &>/dev/null; then
  echo -e "${RED}FAIL: aws sts get-caller-identity failed. Check AWS_PROFILE ($AWS_PROFILE).${NC}"
  exit 1
fi
echo -e "AWS identity: ${GREEN}OK${NC}"

# Optional: kubectl cluster access (cluster may not exist yet)
if kubectl cluster-info &>/dev/null; then
  echo -e "kubectl cluster: ${GREEN}OK${NC}"
else
  echo -e "${YELLOW}kubectl cluster: not reachable (run after make kubeconfig)${NC}"
fi

echo "========================================"
echo -e "${GREEN}Preflight passed.${NC}"
echo "========================================"
