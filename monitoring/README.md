# monitoring/ — Evidence Plane: Prometheus, OpenTelemetry, Loki/Grafana

**Reference:** CHAPTER3_REFERENCE.md §3.1 Observability principle and **Table 1 Evidence Plane**.

Implements the observability and evidence-collection stack for drift detection, policy-denial visibility, and audit trails as defined in Chapter 3.1 and Table 1.

---

## Table 1 Evidence Plane mapping (this repo)

| Tool / Component   | Layer              | Plane Role   | Purpose here | Artifacts |
|--------------------|--------------------|-------------|--------------|-----------|
| **Prometheus**     | All layers         | Evidence    | Metrics, alerting on drift/policy denial | Time series, alert history |
| **OpenTelemetry**  | All layers         | Evidence    | Traces, metrics, logs; correlated signals | Spans, correlated signals |
| **Loki**           | All layers         | Evidence    | Log aggregation (with Grafana) | Indexed logs |
| **Grafana**        | All layers         | Evidence    | Dashboards, log query UI | Dashboards (Argo CD sync, Gatekeeper audit) |

Alerts target **drift** (Argo CD OutOfSync/SyncFailed) and **policy denial** (Gatekeeper constraint violations / audit failure), plus firewall workload health.

---

## Layout

```
monitoring/
├── README.md                    # This file
├── prometheus/
│   ├── alerts.yaml              # PrometheusRule: Argo CD, Gatekeeper, Firewall
│   ├── servicemonitor-gatekeeper.yaml
│   └── gatekeeper-podmonitor.yaml  # Optional: use if ServiceMonitor port name differs
├── otel/
│   └── collector-config.yaml    # OpenTelemetry Collector config (traces/metrics/logs)
├── loki/
│   └── loki-config.yaml         # Loki server config (reference)
└── grafana/
    └── dashboards/
        ├── argocd-sync.json     # Argo CD sync status, drift
        └── gatekeeper-audit.json # Gatekeeper violations, policy denials
```

---

## Apply steps

Prerequisites: cluster with **kube-prometheus-stack** (or Prometheus Operator) and optional Loki/OpenTelemetry/Grafana.

1. **Create namespace** (if not present):
   ```bash
   kubectl create namespace monitoring
   ```

2. **Prometheus alerts (PrometheusRule)**  
   Ensure the Prometheus Operator is configured to select this rule (e.g. same label as other rules, e.g. `release: kube-prometheus-stack`):
   ```bash
   kubectl apply -f prometheus/alerts.yaml
   ```
   Alerts: `ArgoCDAppOutOfSync`, `ArgoCDAppSyncFailed`, `GatekeeperConstraintViolations`, `GatekeeperAuditRunFailure`, `FirewallPodNotReady`.

3. **Gatekeeper metrics (ServiceMonitor or PodMonitor)**  
   So Prometheus scrapes Gatekeeper controller metrics (constraint violations, audit):
   ```bash
   kubectl apply -f prometheus/servicemonitor-gatekeeper.yaml
   ```
   If the Service has no port named `metrics`, use the PodMonitor instead (same release label):
   ```bash
   kubectl apply -f prometheus/gatekeeper-podmonitor.yaml
   ```

4. **OpenTelemetry Collector**  
   Apply the Collector ConfigMap (config lives under `data.config.yaml`); then deploy an OpenTelemetry Collector that mounts it (e.g. `config.yaml` from this ConfigMap):
   ```bash
   kubectl apply -f otel/collector-config.yaml
   ```
   Pipelines: OTLP → traces/metrics/logs with batch and memory_limiter; exporters: logging and Prometheus (metrics).

5. **Loki**  
   Use `loki/loki-config.yaml` as reference (e.g. `helm install loki grafana/loki-stack` or Grafana Cloud). No direct `kubectl apply` for the full server; adapt to your Loki deployment.

6. **Grafana dashboards**  
   Import JSON dashboards from `grafana/dashboards/`:
   - **argocd-sync.json** — Argo CD applications, sync_status, OutOfSync count, sync operations.
   - **gatekeeper-audit.json** — Gatekeeper constraint violations (policy denials), total and rate.

   Set the Prometheus datasource variable after import. Dashboards use metrics: `argocd_app_info`, `argocd_app_sync_total`, `gatekeeper_constraint_violations_total`.

---

## Alert summary (drift & policy denial)

| Alert                         | Condition | Purpose |
|------------------------------|-----------|---------|
| ArgoCDAppOutOfSync           | App OutOfSync for 1m | Drift detection |
| ArgoCDAppSyncFailed          | Sync failed for 2m | Reconciliation failure |
| GatekeeperConstraintViolations | Violations > 0 for 5m | Policy denial evidence |
| GatekeeperAuditRunFailure    | Audit run failure | Audit pipeline health |
| FirewallPodNotReady          | No ready pods in `firewall` ns for 2m | Workload health |

These support §3.1 observability and Table 1 Evidence Plane requirements for operational resilience and compliance evidence.
