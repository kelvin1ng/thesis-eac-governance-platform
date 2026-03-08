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

echo "=== Phase 0 — Local prep (WSL) ==="

# Require Linux/WSL
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "ERROR: This script must run on Linux/WSL. uname -s=$(uname -s)"
  exit 1
fi

echo "Shell: $SHELL"
echo "uname: $(uname -a)"
echo "pwd: $(pwd)"

cd "$REPO_ROOT"
echo "Repo root: $REPO_ROOT"

# Repo must be under /home/, not under /mnt/c or other Windows mounts
if [[ "$REPO_ROOT" == /mnt/c/* ]] || [[ "$REPO_ROOT" == /mnt/* ]]; then
  echo "ERROR: Repo is under a Windows mount ($REPO_ROOT). Copy the repo into the WSL filesystem (e.g. /home/kkfng/projects/thesis-eac-governance-platform) and run from there."
  exit 1
fi
if [[ "$REPO_ROOT" != /home/* ]]; then
  echo "WARNING: Repo root is not under /home/ ($REPO_ROOT). Prefer cloning under /home/ for WSL."
fi

# Validate required CLIs
MISSING=()
for cmd in aws terraform kubectl helm jq git dos2unix; do
  if ! command -v "$cmd" &>/dev/null; then
    MISSING+=("$cmd")
  fi
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "ERROR: Missing required tools: ${MISSING[*]}"
  echo "Install with: sudo apt install awscli terraform kubectl helm jq git dos2unix (or use official installers)"
  exit 1
fi

aws --version
terraform version
kubectl version --client
helm version
jq --version
git --version
dos2unix --version

# Normalize line endings for all .sh files
find . -name '*.sh' -exec dos2unix {} \;

# Make scripts executable (idempotent)
chmod +x scripts/*.sh 2>/dev/null || true
chmod +x scripts/threat-tests/*.sh 2>/dev/null || true
chmod +x scripts/deploy/*.sh 2>/dev/null || true

aws sts get-caller-identity

echo "--- ~/.aws ---"
ls -la ~/.aws 2>/dev/null || true
echo "--- ~/.kube ---"
ls -la ~/.kube 2>/dev/null || true

echo ""
echo "Phase 0 complete. Next: run 01-phase1-terraform.sh"
