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

echo "=== Phase 8 — Threat tests and evidence capture ==="

cd "$REPO_ROOT"

LOG_FILE="threat-tests-$(date +%Y%m%d-%H%M%S).log"

./scripts/threat-tests/run-all.sh 2>&1 | tee "$LOG_FILE"

