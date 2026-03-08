#!/usr/bin/env bash
# Table 3 Threat 2: Unauthorized pipeline change within the continuous integration repository
# CHAPTER3_REFERENCE.md §3.6. Preventive: CODEOWNERS for pipelines/policies; signed commits/tags.
# Detective: repo audit logs, pipeline behavior alerts. Corrective: Git revert, credential rotation.
# This script verifies CODEOWNERS cover policies/, pipelines/, and .github/ (preventive).

set -euo pipefail
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_ROOT"

echo "[threat-2] Unauthorized pipeline change — validating Table 3 preventive controls (CODEOWNERS)"

CODEOWNERS_FILE=""
for f in .github/CODEOWNERS CODEOWNERS; do
  if [[ -f "$f" ]]; then CODEOWNERS_FILE="$f"; break; fi
done
if [[ -z "$CODEOWNERS_FILE" ]]; then
  echo "  [FAIL] No CODEOWNERS file found"
  exit 1
fi
echo "  [OK] Using $CODEOWNERS_FILE"

MISSING=()
grep -qE '^/policies/' "$CODEOWNERS_FILE" || MISSING+=(/policies/)
grep -qE '^/pipelines/' "$CODEOWNERS_FILE" || MISSING+=(/pipelines/)
grep -qE '\.github' "$CODEOWNERS_FILE" || MISSING+=(.github)

if [[ ${#MISSING[@]} -eq 0 ]]; then
  echo "  [OK] Preventive: CODEOWNERS covers /policies/, /pipelines/, .github (Table 3 [50])"
else
  echo "  [FAIL] CODEOWNERS missing entries for: ${MISSING[*]}"
  exit 1
fi

if [[ -f .github/workflows/path-b-policy-check.yaml ]]; then
  echo "  [OK] Path B policy workflow present (Conftest on policies/pipelines/.github changes)"
else
  echo "  [WARN] .github/workflows/path-b-policy-check.yaml not found"
fi

echo "[threat-2] Done. Detective/corrective: repo audit logs and Git revert — see BRANCH-PROTECTION.md and CODEOWNERS."
