# Chapter 4 Evidence Package

**Reference:** Thesis Chapter 4 (Implementation and Evaluation); CHAPTER3_REFERENCE.md and PROJECT_PLAN.md.

Checklist of artifacts and steps to capture for Chapter 4 evidence.

---

## 1. Architecture and principles

| Principle (§3.1) | Evidence | Location |
|------------------|----------|----------|
| Modularity | Four layers as separate dirs; module boundaries | `infra/`, `policies/`, `pipelines/`, `argocd/`, `apps/firewall/` |
| Declarativity | All config as YAML/HCL; Git as source of truth | Repo structure; Argo CD Applications |
| Immutability | Branch protection, digest-only, ECR config, single-writer | `.github/BRANCH-PROTECTION.md`, `CODEOWNERS`, `argocd/`, `infra/ecr.tf` |
| Observability | Prometheus alerts, OTel, Loki ref, Grafana dashboards | `monitoring/`; Data source–managed rules; screenshots |
| Traceability | Chains config, SBOM/cosign in pipeline, signed commits docs | `pipelines/chains-config.yaml`, pipeline tasks, README |

**Capture:** Screenshot or table mapping each principle to repo paths and a representative file.

---

## 2. Table 3 threat controls

| Threat | Preventive | Detective | Corrective | Evidence to capture |
|--------|------------|-----------|------------|---------------------|
| 1. Unauthorized manifest | Branch protection, PR checks | Argo CD drift alerts | Argo CD selfHeal | Branch protection settings; Argo CD sync status / alert |
| 2. Unauthorized pipeline | CODEOWNERS | Repo audit / Path B workflow | Git revert | CODEOWNERS files; path-b-policy-check workflow |
| 3. Artifact tampering | Allowlist, cosign, SBOM | Trivy, registry audit | Immutable restore | Gatekeeper constraints; pipeline Trivy/cosign; denial test output |
| 4. Direct kubectl | Argo CD Project/RBAC | Prometheus alerts | Self-heal | Threat test 4 output (label reverted); Argo CD syncPolicy |
| 5. Policy bypass | Gatekeeper admission | Denial alerts | Rego/key rotation | Threat test 5 output (denial); GatekeeperConstraintViolations alert |

**Capture:** Run `./scripts/threat-tests/run-all.sh` and save stdout. Screenshot Prometheus/Grafana for alerts and Gatekeeper/Argo CD dashboards (after threat tests generate data).

---

## 3. Observability (Evidence Plane)

| Item | Location | Evidence |
|------|----------|----------|
| Prometheus rules | `monitoring/prometheus/alerts.yaml` | Data source–managed view; firing alerts (e.g. after threat tests) |
| Gatekeeper ServiceMonitor | `monitoring/prometheus/servicemonitor-gatekeeper.yaml` | Gatekeeper metrics scraped |
| Grafana dashboards | `monitoring/grafana/dashboards/argocd-sync.json`, `gatekeeper-audit.json` | Import and screenshot (Argo CD sync, Gatekeeper violations) |
| OpenTelemetry | `monitoring/otel/collector-config.yaml` | Config applied; optional trace/metrics screenshot |
| Loki | `monitoring/loki/loki-config.yaml` | Reference config; optional log view screenshot |

**Capture:** Screenshots of Grafana dashboards and Prometheus alert rules list; optional alert firing state.

---

## 4. Deployment and reproducibility

| Item | Evidence |
|------|----------|
| Local bootstrap | `./scripts/bootstrap-kind.sh` run; `kubectl get nodes` and Argo CD / Tekton / Gatekeeper ready |
| EKS (optional) | Terraform apply; `aws eks update-kubeconfig`; same apply order as DEPLOYMENT.md |
| Apply order | Follow `DEPLOYMENT.md`; document any env-specific overrides (e.g. repoURL, registry) |

**Capture:** Short runbook or table of commands used (from DEPLOYMENT.md) and final cluster state (namespaces, Argo CD apps Synced).

---

## 5. Suggested screenshot list (Ch4)

1. **CODEOWNERS** — root and `.github/` showing policies/, pipelines/, .github/
2. **Branch protection** — GitHub settings or BRANCH-PROTECTION.md
3. **Workflows** — `.github/workflows/` folder (pr-checks, path-b-policy-check)
4. **Prometheus** — Custom rules (thesis-eac-alerts) in Data source–managed view
5. **Grafana** — Argo CD Sync and Gatekeeper Audit dashboards (with data if possible)
6. **Threat tests** — Terminal output of `run-all.sh` or individual threat scripts
7. **Argo CD** — Application list and firewall app Synced; syncPolicy (selfHeal/prune)
8. **Gatekeeper** — Constraint list and (optional) violation/audit metric in Grafana

Store screenshots in a folder (e.g. `docs/ch4-screenshots/`) or thesis appendix; reference this document and PROJECT_PLAN.md in Chapter 4.
