#!/usr/bin/env bash
# Run all Table 3 threat tests (CHAPTER3_REFERENCE.md §3.6). For Step 9 and Ch4 evidence.
set -euo pipefail
DIR="$(dirname "${BASH_SOURCE[0]}")"
for s in 1-unauthorized-manifest.sh 2-unauthorized-pipeline.sh 3-artifact-tampering.sh 4-direct-kubectl.sh 5-policy-bypass.sh; do
  "$DIR/$s" || true
  echo ""
done
echo "Table 3 threat test run complete."
