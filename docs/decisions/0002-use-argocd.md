# ADR 0002: Use Argo CD for GitOps

## Status

Accepted.

## Context

The architecture requires a single-writer, pull-based CD model (CHAPTER3_REFERENCE §3.2.4, Table 1). Drift must be detectable and correctable via Git; no direct kubectl apply as source of truth for app/policy manifests.

## Decision

Use **Argo CD** for continuous delivery. Applications sync from Git; AppProject scopes source repos and destinations; RBAC restricts who can change Applications. Automated sync with prune and selfHeal for corrective control (Table 3).

## Consequences

- All workload and policy manifests are Git-sourced; Argo CD is the only writer for those namespaces.
- Drift appears as OutOfSync; Prometheus/alerting can detect it. Runbooks cover troubleshooting (docs/runbooks/argocd-troubleshooting.md).
- Requires Argo CD installed and Applications configured; repo URL and path must match AppProject sourceRepos.
