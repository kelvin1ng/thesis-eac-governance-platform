# Runbook: Monitoring troubleshooting

## Stack

- Helm release: `kps` (kube-prometheus-stack), namespace: `monitoring`.
- Custom: PrometheusRule `thesis-eac-alerts`, ServiceMonitor/PodMonitor for Gatekeeper; labels must match release `kps`.

## Common issues

### No Prometheus/Grafana targets or data

- **Check:** `kubectl get pods -n monitoring`, `kubectl get prometheusrules -n monitoring`, `kubectl get servicemonitors -A`
- **Actions:** Ensure custom rules and monitors have label `release=kps`. Re-apply and re-label:
  ```bash
  kubectl apply -f monitoring/prometheus/alerts.yaml
  kubectl label prometheusrule thesis-eac-alerts -n monitoring release=kps --overwrite
  ```
- **Verify:** Prometheus UI → Status → Targets; Configuration → Rules.

### Grafana "No data"

- **Check:** Datasource in Grafana set to Prometheus; time range and query correct.
- **Actions:** Confirm Prometheus is scraping (targets UP). For Argo CD metrics, Argo CD must expose metrics and be scraped by the stack.
- **Verify:** Run PromQL in Prometheus first (e.g. `up`).

### Alerts not firing

- **Check:** Prometheus → Alerts; rule names `thesis-eac-alerts`.
- **Actions:** Ensure PrometheusRule has label that Prometheus selects (e.g. `release: kps`). Check Prometheus version supports the rule syntax.

## Diagnostics

```bash
kubectl get svc -n monitoring
kubectl get pods -n monitoring
kubectl get prometheusrules -n monitoring
```

## References

- monitoring/README.md, monitoring/prometheus/
- docs/decisions/0004-use-kube-prometheus-stack.md
