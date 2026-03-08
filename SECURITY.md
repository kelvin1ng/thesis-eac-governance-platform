# Security

## Reporting vulnerabilities

If you discover a security issue in this repository or the deployed platform, please report it responsibly:

1. **Do not** open a public GitHub issue for security vulnerabilities.
2. Contact the repository maintainers or your institution’s security contact with a concise description, steps to reproduce, and impact.
3. Allow reasonable time for a fix before any public disclosure.

## Scope

- **In scope:** This repo (scripts, Terraform, policies, Argo CD apps, monitoring config), and the EKS cluster/workloads it provisions.
- **Out of scope:** General AWS or Kubernetes CVEs unless they directly affect our configuration or usage.

## Practices

- **Secrets:** No long-lived credentials in repo; use IAM roles, OIDC, or external secret managers. `backend.hcl` is gitignored; use `backend.hcl.example` as template.
- **Supply chain:** Images built via Tekton; Trivy and Conftest run in CI; Gatekeeper enforces policy at admission. See [CHAPTER3_REFERENCE.md](CHAPTER3_REFERENCE.md) and Table 3 controls.
- **Access:** EKS access via IAM (EKS Access Entry); Argo CD and Grafana have RBAC. Restrict who can merge to `main` and who has AWS/thesis profile access.

## Compliance

Evidence collection for thesis (e.g. `make collect-evidence`) captures cluster state and logs; ensure no sensitive data is included before sharing. See [docs/evidence/](docs/evidence/) and [docs/CHAPTER4-EVIDENCE.md](docs/CHAPTER4-EVIDENCE.md).
