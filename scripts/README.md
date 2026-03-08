# scripts/ — Bootstrap and Demo Scripts

**Reference:** CHAPTER3_REFERENCE.md §3.2 (Layered Architecture), §3.5 (Change Paths), §3.6 (Threat Model Table 3).

This directory contains:

- **Bootstrap (Step 1):** `bootstrap-kind.sh` — local Kind cluster with Tekton, Argo CD, Gatekeeper, Prometheus stack (Table 1 Evidence Plane).
- **Path A (Figure 2):** `run-path-a-demo.sh` — application change flow for firewall workload (to be added in Step 5).
- **Path B (Figure 3):** `run-path-b-demo.sh` — governance change flow for policy/pipeline (to be added in Step 6).
- **Threat tests (Table 3):** `threat-tests/` — scripts validating preventive/detective/corrective controls for all five threats.

Run bootstrap from repo root (use WSL or Git Bash on Windows):

```bash
./scripts/bootstrap-kind.sh
```

Requires: `kind`, `kubectl`, `helm` (for Prometheus stack).
