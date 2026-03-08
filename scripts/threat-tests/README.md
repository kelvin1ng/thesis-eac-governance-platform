# threat-tests/ — Table 3 Threat to Control Validation

**Reference:** CHAPTER3_REFERENCE.md §3.6, Table 3 (Threat to Control Mapping). Figure 4.

Scripts validate preventive, detective, and corrective controls for all five threats.

| # | Threat | Preventive | Detective | Corrective | Script |
|---|--------|------------|-----------|------------|--------|
| 1 | Unauthorized manifest change (GitOps repo) | Protected branches, PR review, required status checks | Audit logs, Argo CD drift alerts | Argo CD auto-sync revert | `1-unauthorized-manifest.sh` |
| 2 | Unauthorized pipeline change (CI repo) | CODEOWNERS (policies/, pipelines/, .github), signed commits/tags | Repo audit logs, pipeline alerts | Git revert, credential rotation | `2-unauthorized-pipeline.sh` |
| 3 | Artifact tampering (registry) | Immutable registry, digest/cosign at admission, SBOM | Registry audit, Trivy scan | Restore immutable state, key revocation | `3-artifact-tampering.sh` |
| 4 | Direct kubectl in production | Argo CD Projects, RBAC, admission | Prometheus alerts on changes | Argo CD self-heal (single-writer) | `4-direct-kubectl.sh` |
| 5 | Policy bypass | OPA/Gatekeeper decoupled from pipeline (admission) | Denial alerts, log aggregation | Harden Rego, key rotation, GitOps re-apply | `5-policy-bypass.sh` |

## How to run

From repo root (or with `REPO_ROOT` set). On Windows use WSL or Git Bash so scripts run with LF line endings (see root README).

```bash
# Run individually
./scripts/threat-tests/1-unauthorized-manifest.sh
./scripts/threat-tests/2-unauthorized-pipeline.sh
./scripts/threat-tests/3-artifact-tampering.sh
./scripts/threat-tests/4-direct-kubectl.sh
./scripts/threat-tests/5-policy-bypass.sh

# Run all (continues on failure per script)
./scripts/threat-tests/run-all.sh
```

**Prerequisites**

- **1, 2:** None (repo-only checks).
- **3:** Optional cluster with Gatekeeper for admission-denial test (non-allowlisted registry).
- **4:** Cluster with Argo CD and firewall app synced to `firewall` namespace (self-heal test).
- **5:** Cluster with Gatekeeper and `K8sRequiredLabels` constraint (denial test in `default` namespace).

Tests that need a cluster skip gracefully when `kubectl` or the required namespaces are missing. Use Kind (bootstrap) or EKS; ensure policies are applied (`scripts/apply-policies.sh`) and Argo CD has synced the firewall app for threat 4.

## Chapter 4 evidence

- Run all scripts and capture stdout/screenshots for Ch4 (control validation).
- Prometheus/Grafana: alert and dashboard evidence for drift and policy denials (Step 8).
- Threat 4 demonstrates corrective control (self-heal); Threat 5 demonstrates preventive (admission denial).

Implemented in Step 9 of PROJECT_PLAN.md.
