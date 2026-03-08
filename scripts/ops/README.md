# scripts/ops/ — Operational utilities

**Cluster:** thesis-eac-eks (us-east-1, profile thesis). **Monitoring:** Helm release `kps`, namespace `monitoring`.

| Script | Purpose |
|--------|---------|
| `eks-health-check.sh` | Validate cluster connectivity, nodes, CoreDNS, Argo CD, Gatekeeper; colored health summary. |
| `grafana-access.sh` | Find Grafana svc in `monitoring`, port-forward to localhost:3000; optional `xdg-open`. |
| `prometheus-access.sh` | Find Prometheus svc in `monitoring`, port-forward to localhost:9090. |
| `aws-cost-check.sh` | Report EKS node groups, EC2, NAT gateways, EIPs, ALBs; warn on NAT (~$30/mo) and >2 nodes. |
| `destroy-cluster.sh` | Confirm with "DESTROY", run `terraform destroy` in infra/, remove kubeconfig context. |

**Run from repo root (WSL).** Optional: use `run-all-phases.sh --health`, `--grafana`, `--prometheus` to invoke health/grafana/prometheus from the orchestrator.
