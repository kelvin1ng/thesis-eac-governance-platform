# Contributing

## Scope

This repository is the implementation for the MASc thesis *Unified Everything-as-Code Governance Platform* (Chapter 3). Contributions should align with the architecture in [CHAPTER3_REFERENCE.md](CHAPTER3_REFERENCE.md) and the plan in [PROJECT_PLAN.md](PROJECT_PLAN.md).

## Workflow

1. **Branch:** Create a feature or fix branch from `main`.
2. **Preflight:** Run `make preflight` (WSL or Linux) before pushing.
3. **CI:** GitHub Actions run shellcheck, Terraform fmt/validate, yamllint, kubeconform, and policy checks on push/PR.
4. **PR:** Open a PR; ensure CI passes. Policy and pipeline changes may require CODEOWNERS review (see `.github/CODEOWNERS`).

## Standards

- **Shell:** Bash, `set -euo pipefail` where appropriate; LF line endings (`.gitattributes`).
- **Terraform:** `terraform fmt`; use `infra/terraform.tfvars` or env-specific `environments/<env>/terraform.tfvars` for variables.
- **YAML/Kubernetes:** 2-space indent; manifests validated by kubeconform in CI.
- **Policy:** Rego in `policies/`; ConstraintTemplates/Constraints follow Gatekeeper conventions; Conftest used in CI.

## Environment

- Use `environments/dev/env.sh` for shared dev values (AWS profile, region, cluster name). Source before running phase scripts if not using Makefile defaults.
- Do not commit secrets or `backend.hcl` with real credentials; use `backend.hcl.example` as template.

## Runbooks and ADRs

- Operational procedures: [docs/runbooks/](docs/runbooks/).
- Architecture decisions: [docs/decisions/](docs/decisions/).
