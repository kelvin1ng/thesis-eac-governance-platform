# thesis-eac-governance-platform — Project Plan

**Reference:** CHAPTER3_REFERENCE.md (full fidelity). Target: minimal viable Go-based containerized virtual firewall CNF with configurable rules (port 8080, netfilter stub for gosec).

---

## 1. Architectural Principles → File / Implementation Mapping

| Principle (3.1) | How Satisfied | Key Artifacts |
|-----------------|----------------|----------------|
| **Modularity** | Four layers as separate dirs; Terraform modules, Gatekeeper ConstraintTemplates, Tekton Tasks/Pipelines, Argo CD Applications as independent units | `infra/`, `policies/`, `pipelines/`, `argocd/`, `apps/firewall/` |
| **Declarativity** | All infra, policies, pipelines, workloads as declarative YAML/HCL; GitOps desired state in Git | All `.tf`, `.rego`, `.yaml` in repo |
| **Immutability** | Branch protection, digest-only refs, ECR immutability, single-writer (Argo CD), cosign at admission | `infra/` ECR config, `policies/` image-signature constraints, `.github/` branch rules |
| **Observability** | Prometheus, OpenTelemetry, Loki/Grafana, Gatekeeper audit metrics, Argo CD sync status | `monitoring/`, Evidence Plane in pipelines |
| **Traceability** | Signed commits/tags, image digests, Tekton Chains in-toto/SLSA, CycloneDX SBOM, cosign | `pipelines/` Chains config, SBOM tasks, `policies/` digest/signature constraints |

---

## 2. Four Layers (3.2) + Table 1 — Exact Tool Mapping

| Layer | Table 1 Tools | Repo Location | Plane |
|-------|----------------|---------------|--------|
| **Layer 1** Infrastructure Provisioning | Terraform (S3 backend, DynamoDB lock) | `infra/` | Execution + governance gates |
| **Layer 2** Policy Enforcement | OPA/Rego, Gatekeeper | `policies/` | Control Plane |
| **Layer 3** Compliance Verification | Conftest, gosec, Trivy, Kaniko, cosign, SBOM (CycloneDX) | `pipelines/`, `apps/firewall/`, `.github/workflows/` | Execution + Evidence |
| **Layer 4** Orchestration and Delivery | Tekton Pipelines, Tekton Chains, Argo CD, Helm, Kustomize | `pipelines/`, `argocd/`, `apps/firewall/` | Control (Argo CD) + Execution (Tekton) + Evidence (Chains) |

Evidence Plane (Table 1): Prometheus, EFK/Fluentd, OpenTelemetry, Gatekeeper audit, SBOM, cosign/Sigstore, SLSA/in-toto → `monitoring/`, pipeline attestations, `infra/` state.

---

## 3. Platform-Centric Model (3.3, Table 2)

- **Locus of control:** Platform (Argo CD pulls); pipeline (Tekton) only builds and commits manifests → `argocd/`, `pipelines/`.
- **Authority boundary:** Cluster admission (Gatekeeper) → `policies/` ConstraintTemplates/Constraints.
- **Policy enforcement point:** Kubernetes admission controller (Gatekeeper) → `policies/`.

---

## 4. Change Paths (3.5, Figures 2 & 3)

- **Path A (Figure 2):** App code → Git (protected) → Tekton (gosec → Kaniko → Trivy/SBOM → Conftest → cosign/Chains) → Argo CD reconcile after Gatekeeper admission → observability. Files: `apps/firewall/`, `pipelines/` (Path A pipeline), `argocd/` app for firewall, `monitoring/`.
- **Path B (Figure 3):** Governance (Rego/pipeline/Terraform) → CODEOWNERS review → CI (Conftest for policies) → signed release → Argo CD rollout → monitoring. Files: `policies/`, `pipelines/` (policy validation), `.github/CODEOWNERS`, `scripts/` for Path B demo.

---

## 5. Threat Model (3.6, Table 3) → Controls Implementation

| Threat | Preventive | Detective | Corrective | Where Implemented |
|--------|------------|-----------|------------|--------------------|
| Unauthorized manifest change | Protected branches, PR review, required status checks | Audit logs, Argo CD drift alerts | Argo CD auto-sync revert | `.github/` branch protection, `argocd/`, `monitoring/` |
| Unauthorized pipeline change | CODEOWNERS for pipelines/policies, signed commits/tags | Repo audit logs, pipeline behavior alerts | Git revert, credential rotation | `CODEOWNERS`, `.github/`, `scripts/` |
| Artifact tampering | Immutable registry, digest-only, cosign at admission, SBOM | Registry audit, Trivy scan | Restore from immutable state, key revocation | `infra/` ECR, `policies/` image constraints, `pipelines/` |
| Direct kubectl in prod | Argo CD Projects, RBAC, admission deny direct apply in prod ns | Prometheus alerts on unexpected changes | Argo CD self-heal | `argocd/` Projects/RBAC, `policies/` |
| Policy bypass | OPA/Gatekeeper decoupled from pipeline (admission) | Denial alerts, EFK aggregation | Harden Rego, key rotation, GitOps re-apply | `policies/`, `monitoring/` |

---

## 6. Repo Structure — Complete File List with CHAPTER3 References

```
thesis-eac-governance-platform/
├── infra/                                    # 3.2.1 Layer 1 – Terraform
│   ├── backend.tf                            # 3.1 Immutability; Table 1 Terraform state + locking
│   ├── main.tf                               # 3.2.1 EKS, VPC, IAM, tagging for policy linkage
│   ├── ecr.tf                                # 3.1 Immutability; immutable image tags/digests
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md                             # Layer 1 scope, S3 + DynamoDB (profile: thesis)
│
├── policies/                                 # 3.2.2 Layer 2 – OPA/Gatekeeper
│   ├── templates/                            # Gatekeeper ConstraintTemplates (Table 1)
│   │   ├── image-registry-allowlist.yaml     # 3.2.2 image allowlist
│   │   ├── image-signature-cosign.yaml       # 3.2.2 signature verification; Table 3 artifact tampering
│   │   ├── required-labels.yaml              # 3.2.2 traceability labels
│   │   └── firewall-networking.yaml          # 3.2.2 privileged/hostNet/capabilities for firewall
│   ├── constraints/                          # Gatekeeper Constraints (instances)
│   │   ├── allowlist.yaml
│   │   ├── cosign.yaml
│   │   ├── labels.yaml
│   │   └── firewall-networking.yaml
│   ├── rego/                                 # Rego libs for Conftest (CI) and Gatekeeper
│   │   ├── image.rego
│   │   ├── labels.rego
│   │   └── networking.rego
│   └── README.md                             # 3.2.2 policy categories
│
├── pipelines/                                # 3.2.4 Layer 4 – Tekton; Table 1
│   ├── tasks/
│   │   ├── gosec.yaml                        # 3.2.3 Compliance Verification; Table 1 gosec
│   │   ├── kaniko-build.yaml                 # 3.2.3 Kaniko; Table 1
│   │   ├── trivy-sbom.yaml                   # 3.2.3 Trivy + CycloneDX SBOM; Table 1, 3.1 Traceability
│   │   ├── conftest.yaml                     # 3.2.3 Conftest; Table 1
│   │   ├── cosign-sign.yaml                  # Table 1 Sigstore/cosign; 3.1 Traceability
│   │   └── cosign-attest.yaml
│   ├── pipelines/
│   │   ├── path-a-firewall.yaml              # Figure 2 Path A: gosec → Kaniko → Trivy/SBOM → Conftest → cosign
│   │   └── path-b-governance.yaml            # Figure 3 Path B: Conftest policy validation
│   ├── chains-config.yaml                    # Tekton Chains in-toto/SLSA; 3.1 Traceability; Table 1
│   └── README.md
│
├── apps/firewall/                            # Target workload – virtual firewall CNF
│   ├── cmd/firewall/main.go                  # 3.0 virtual firewall; port 8080, configurable rules
│   ├── pkg/rule/rule.go                      # Packet inspection rules (netfilter stub for gosec)
│   ├── Dockerfile                            # Kaniko-ready (no daemon)
│   ├── go.mod
│   ├── go.sum
│   ├── helm/                                 # Table 1 Helm
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       └── _helpers.tpl
│   ├── kustomize/                            # Table 1 Kustomize
│   │   ├── base/
│   │   │   ├── kustomization.yaml
│   │   │   ├── deployment.yaml
│   │   │   └── service.yaml
│   │   └── overlays/dev/
│   │       └── kustomization.yaml
│   └── README.md
│
├── .github/
│   ├── workflows/
│   │   ├── pr-checks.yaml                    # gosec, Trivy, Conftest on PR; Table 3 preventive
│   │   └── path-b-policy-check.yaml          # Conftest for policies/ on policy PRs
│   ├── CODEOWNERS                            # 3.5 Path B; Table 3 pipeline/policy CODEOWNERS
│   └── (branch protection: docs in README)  # Table 3 unauthorized manifest/pipeline change
│
├── argocd/                                   # 3.2.4 Layer 4; Table 1 Argo CD; Table 2 platform-centric
│   ├── project-thesis.yaml                   # 3.3 Argo CD Project; Table 3 RBAC/Projects
│   ├── application-firewall.yaml             # Path A app; digest-only refs
│   ├── application-policies.yaml             # Optional: policy rollout
│   ├── rbac.yaml                             # Table 3 RBAC
│   └── README.md
│
├── monitoring/                               # 3.1 Observability; Table 1 Evidence Plane
│   ├── prometheus/                           # Table 1 Prometheus
│   │   ├── prometheus.yaml
│   │   ├── alerts.yaml                       # Drift, policy denials, Table 3 detective
│   │   └── servicemonitor-gatekeeper.yaml
│   ├── otel/                                 # Table 1 OpenTelemetry
│   │   └── collector-config.yaml
│   ├── loki/                                 # Log aggregation (Loki/Grafana)
│   │   └── loki-config.yaml
│   ├── grafana/
│   │   └── dashboards/
│   │       ├── argocd-sync.json
│   │       └── gatekeeper-audit.json
│   └── README.md
│
├── scripts/                                  # Bootstrap and demos
│   ├── bootstrap-kind.sh                     # Step 1: Kind + Tekton, Argo CD, Gatekeeper, Prometheus
│   ├── run-path-a-demo.sh                    # Path A (Figure 2) end-to-end
│   ├── run-path-b-demo.sh                    # Path B (Figure 3) policy change
│   ├── threat-tests/                         # Table 3 threat tests
│   │   ├── 1-unauthorized-manifest.sh
│   │   ├── 2-unauthorized-pipeline.sh
│   │   ├── 3-artifact-tampering.sh
│   │   ├── 4-direct-kubectl.sh
│   │   └── 5-policy-bypass.sh
│   └── README.md
│
├── CHAPTER3_REFERENCE.md                     # Mandatory reference (unchanged)
├── PROJECT_PLAN.md                            # This file
├── README.md                                 # Setup, Path A/B, principles, Ch4 evidence
├── CODEOWNERS                                # Root CODEOWNERS (policies/, pipelines/)
└── .github/CODEOWNERS                        # Same as above or more specific
```

---

## 7. Implementation Order (Steps 1–10)

| Step | Scope | Deliverables |
|------|--------|--------------|
| **1** | Bootstrap (local) | Kind cluster; install Tekton, Argo CD, Gatekeeper, Prometheus stack; `scripts/bootstrap-kind.sh` + optional kustomize/helm for install |
| **2** | Layer 1 | Terraform: S3 backend + DynamoDB lock (profile `thesis`), EKS, ECR immutability, VPC, IAM |
| **3** | Layer 2 | Gatekeeper ConstraintTemplates + Constraints (image allowlist, cosign, labels, firewall networking) |
| **4** | Minimal firewall app | Go app (port 8080, rules, netfilter stub), Dockerfile (Kaniko-ready), Helm + Kustomize |
| **5** | Layer 3/4 pipeline | Tekton Pipeline Path A: gosec → Kaniko → Trivy + CycloneDX SBOM → Conftest → cosign + Tekton Chains |
| **6** | Argo CD | Applications, Projects, RBAC, auto-sync; digest-only |
| **7** | Git protections | Protected branches, CODEOWNERS for `policies/` (and pipelines), required status checks (docs + optional GH config) |
| **8** | Observability + Evidence | Prometheus/OpenTelemetry/Loki/Grafana; evidence collection for Ch4 |
| **9** | Threat tests | Scripts for all five Table 3 threats (preventive/detective/corrective) |
| **10** | README | Local setup, AWS EKS migration, Path A/B demos, principle mapping, Ch4-ready evidence |

---

## 8. Traceability Checklist (3.1 Traceability; Table 1)

- Signed commits/tags: documented in README; enforced via branch protection.
- Image digests only: Argo CD app and Gatekeeper constraints reference by digest.
- Tekton Chains: in-toto/SLSA attestations configured in `pipelines/chains-config.yaml`.
- SBOM: CycloneDX from Trivy in pipeline; stored as evidence.
- cosign: sign after build; verify in Gatekeeper admission.

---

*All files in the repo MUST include comments referencing exact sections/tables from CHAPTER3_REFERENCE.md (e.g. "3.2.2 Layer 2", "Table 1", "Table 3").*
