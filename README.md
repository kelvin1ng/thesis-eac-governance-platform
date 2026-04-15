# thesis-eac-governance-platform

Unified Everything-as-Code (EaC) governance platform — MASc thesis implementation (Chapter 3). Production-style layout for infrastructure, policy, GitOps, and observability.

**References:** [PROJECT_PLAN.md](PROJECT_PLAN.md).

---

## Platform overview

- **Layer 1 (Infra):** Terraform — EKS, VPC, IAM, ECR; S3 + DynamoDB backend; AWS profile `thesis`, region `us-east-1`.
- **Layer 2 (Policy):** OPA Gatekeeper — ConstraintTemplates/Constraints; Rego shared with Conftest in CI.
- **Control plane:** Argo CD — GitOps; Applications sync from this repo.
- **Evidence plane:** kube-prometheus-stack (Prometheus, Grafana, alerts); Gatekeeper/Argo CD metrics.
- **Pipelines:** Tekton (Path A app build, Path B policy); gosec, Trivy, Conftest, cosign.

Target workload: minimal Go-based virtual firewall CNF (port 8080, configurable rules). Architecture follows five principles (Modularity, Declarativity, Immutability, Observability, Traceability) and Table 3 threat controls.

---

## Architecture summary

| Layer   | Tool / component      | Location / note                    |
|---------|------------------------|------------------------------------|
| Infra   | Terraform (EKS, ECR, VPC) | `infra/`                          |
| Policy  | Gatekeeper + Rego     | `policies/`                        |
| Control | Argo CD               | `argocd/` (Applications, AppProject) |
| Evidence| kube-prometheus-stack | `monitoring/`; Helm release `kps`  |
| Pipelines | Tekton               | `pipelines/`                       |

Runbooks: [docs/runbooks/](docs/runbooks/). Decisions: [docs/decisions/](docs/decisions/).

---

## Prerequisites

- **WSL or Linux** (scripts assume Bash, LF).
- Binaries: `git`, `aws`, `terraform`, `kubectl`, `helm`.
- AWS profile `thesis` with access to create EKS, VPC, S3, DynamoDB in `us-east-1`.
- (Optional) `shellcheck`, `yamllint`, `terraform` in PATH for `make ci-local`.

---

## Quickstart

```bash
# From repo root (WSL path: /home/kkfng/projects/thesis-eac-governance-platform)
git clone <repo> && cd thesis-eac-governance-platform

# Load dev environment (optional; Makefile has defaults)
source environments/dev/env.sh

# Preflight: repo, path, binaries, AWS identity, kubectl if cluster exists
make preflight

# Full deploy (prep → infra → kubeconfig → addons → policies → argocd → monitoring)
make deploy
```

---

## Deploy flow

1. **prep** — Local prep (deps, backend hint).
2. **infra** — Terraform apply (EKS, VPC, ECR, etc.); uses `environments/dev/terraform.tfvars`.
3. **kubeconfig** — `aws eks update-kubeconfig` for cluster `thesis-eac-eks`.
4. **addons** — Gatekeeper + Argo CD (Helm).
5. **policies** — Gatekeeper ConstraintTemplates and Constraints.
6. **argocd** — Argo CD Applications (apps, policies, monitoring).
7. **monitoring** — kube-prometheus-stack (release `kps`).

Single command: `make deploy`. Per-phase: `make prep`, `make infra`, … (see `make help`).

---

## Verification flow

- **Smoke tests (non-destructive):** `make smoke` — cluster, Argo CD, Gatekeeper, monitoring.
- **Verification phase:** `make verify` — runs phase 7 checks.
- **Threat tests:** `make threat-tests` — Table 3 threat suite.
- **Health:** `make health` — EKS health check.
- **Evidence:** `make collect-evidence` — snapshot to `docs/evidence/<timestamp>/` for thesis artifacts.

---

## Destroy flow

1. Tear down Argo CD–managed resources (or let Argo CD prune).
2. Uninstall Helm releases (monitoring, Argo CD, Gatekeeper).
3. **make destroy** — runs `scripts/ops/destroy-cluster.sh` (Terraform destroy).
4. Remove Terraform state backend (S3/DynamoDB) if desired; see [docs/runbooks/destroy-and-cleanup.md](docs/runbooks/destroy-and-cleanup.md).

---

## Repository structure

```
├── .github/workflows/     # CI: shellcheck, Terraform, yamllint, kubeconform, policy, Trivy
├── apps/                  # Application workloads (e.g. firewall)
├── argocd/                # Argo CD Application/Project manifests
├── docs/
│   ├── architecture/      # Architecture docs
│   ├── runbooks/          # Operational runbooks
│   ├── decisions/         # ADRs (0001–0004)
│   └── evidence/          # Timestamped evidence snapshots (make collect-evidence)
├── environments/dev/      # Dev env contract: env.sh, cluster.env, terraform.tfvars
├── infra/                 # Terraform (EKS, VPC, ECR, backend)
├── monitoring/            # Prometheus/Grafana rules and dashboards
├── pipelines/             # Tekton pipelines
├── policies/              # Gatekeeper Rego, ConstraintTemplates, Constraints
├── scripts/
│   ├── deploy/            # Phase scripts (00–08)
│   ├── ops/               # preflight-check, collect-evidence, health, destroy, etc.
│   └── phases/            # Optional phase helpers
├── tests/
│   ├── smoke/             # check-cluster, check-argocd, check-gatekeeper, check-monitoring
│   ├── policy/            # Policy test fixtures
│   └── security/         # Security-focused tests
├── Makefile               # prep, deploy, verify, smoke, preflight, collect-evidence, ci-local
├── CONTRIBUTING.md
└── SECURITY.md
```

---

## Thesis / research context

This repo implements the platform described in Chapter 3 of the thesis: four layers (Infra, Policy, Control, Evidence), platform-centric CD (Argo CD as single writer), and Table 3 threat controls. Evidence for Chapter 4 is collected via `make collect-evidence` and documented in [docs/CHAPTER4-EVIDENCE.md](docs/CHAPTER4-EVIDENCE.md). All design choices are recorded in [docs/decisions/](docs/decisions/).

---

## Make targets (summary)

| Target            | Description                    |
|-------------------|--------------------------------|
| `make preflight`  | Run preflight-check.sh         |
| `make deploy`     | Full deployment pipeline       |
| `make smoke`      | Run smoke tests                |
| `make verify-all` | verify + threat-tests + health |
| `make collect-evidence` | Snapshot cluster state to docs/evidence |
| `make ci-local`   | Run CI-style checks locally    |
| `make destroy`    | Destroy cluster (see runbook)   |
| `make help`       | List all targets               |

*Shell scripts use LF line endings. On Windows, run from WSL or Git Bash.
