# ADR 0003: Use OPA Gatekeeper for admission

## Status

Accepted.

## Context

Policy must be enforced at the platform boundary (admission), decoupled from CI (Table 3). We need Kubernetes-native policy (image allowlist, labels, signatures) without embedding policy in pipeline code.

## Decision

Use **Open Policy Agent (OPA) Gatekeeper** for admission control. ConstraintTemplates and Constraints live in `policies/`; Rego shared with Conftest for CI. Gatekeeper runs in-cluster; metrics exposed for Prometheus (Evidence Plane).

## Consequences

- Admission is consistent regardless of how resources are applied (Argo CD, kubectl). Policy bypass requires compromising the cluster, not the pipeline.
- ConstraintTemplates must be installed before Constraints; runbooks cover CRD readiness and troubleshooting (docs/runbooks/gatekeeper-troubleshooting.md).
- Gatekeeper controller needs minimal resources on small node groups; we tune memory for t3.medium.
