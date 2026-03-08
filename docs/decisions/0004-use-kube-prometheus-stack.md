# ADR 0004: Use kube-prometheus-stack for observability

## Status

Accepted.

## Context

Observability (CHAPTER3 §3.1, Table 1) requires metrics, alerting, and dashboards for drift (Argo CD) and policy denials (Gatekeeper). We need a single Helm chart that provides Prometheus, Grafana, and operator for ServiceMonitors/PodMonitors/PrometheusRules.

## Decision

Use **kube-prometheus-stack** (Prometheus Community Helm chart) with release name `kps`. Add custom PrometheusRule (alerts) and ServiceMonitor/PodMonitor for Gatekeeper; label resources with `release=kps` so the stack’s Prometheus selects them. Grafana dashboards (Argo CD sync, Gatekeeper audit) imported from repo.

## Consequences

- One Helm install provides Prometheus, Grafana, and operator; we avoid managing Prometheus config by hand.
- Custom rules and monitors must use the same release label as the install; runbooks document re-labeling (docs/runbooks/monitoring-troubleshooting.md).
- Resource usage on small clusters may require tuning; we rely on defaults with optional resource limits.
