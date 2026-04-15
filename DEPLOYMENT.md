# Deployment Instructions

**Reference:** PROJECT_PLAN.md Steps 1–10.

Deployment order and prerequisites for local (Kind) and AWS EKS.

---

## Prerequisites

- **Local (Kind):** `kind`, `kubectl`, `helm`, WSL or Git Bash on Windows.
- **EKS:** AWS CLI, `terraform`, profile `thesis`; S3 + DynamoDB backend for Terraform state (see `infra/README.md`).

---

## 1. Local (Kind) — full stack

From repo root:

```bash
# 1. Cluster + Tekton, Argo CD, Gatekeeper, kube-prometheus-stack
./scripts/bootstrap-kind.sh

# 2. Use cluster
kubectl config use-context kind-thesis-eac

# 3. Apply Gatekeeper policies (ConstraintTemplates + Constraints)
./scripts/apply-policies.sh

# 4. Argo CD: create Project and Applications (update repoURL in application-*.yaml if needed)
kubectl apply -f argocd/project-thesis.yaml
kubectl apply -f argocd/application-firewall.yaml
kubectl apply -f argocd/application-policies.yaml
# Optional: Argo CD RBAC
kubectl apply -f argocd/rbac.yaml

# 5. Monitoring: Prometheus rules + Gatekeeper ServiceMonitor (and optional PodMonitor)
kubectl apply -f monitoring/prometheus/alerts.yaml
kubectl apply -f monitoring/prometheus/servicemonitor-gatekeeper.yaml
# Optional if Service has no metrics port: kubectl apply -f monitoring/prometheus/gatekeeper-podmonitor.yaml

# 6. (Optional) OpenTelemetry Collector config
kubectl apply -f monitoring/otel/collector-config.yaml
# Then deploy an OTel Collector that mounts the ConfigMap (see monitoring/README.md).

# 7. Access UIs
kubectl port-forward svc/argocd-server -n argocd 8080:443
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
# Argo CD: https://localhost:8080   Grafana: http://localhost:3000
```

Sync the firewall app in Argo CD (or wait for auto-sync). Then run threat tests:

```bash
./scripts/threat-tests/run-all.sh
```

---

## 2. AWS EKS

```bash
# 1. Terraform backend (one-time)
AWS_PROFILE=thesis ./scripts/create-terraform-backend.sh
# Copy infra/backend.hcl.example → infra/backend.hcl, then:

cd infra
terraform init -backend-config=backend.hcl
terraform apply

# 2. Kubeconfig
aws eks update-kubeconfig --region us-east-1 --name thesis-eac-eks --profile thesis

# 3. Same as Kind from step 3 onward: apply policies, Argo CD apps, monitoring, threat tests.
# Use the same kubectl apply commands as in section 1 (steps 3–6).
```

---

## 3. Apply order summary

| Order | Component | Command / location |
|-------|-----------|--------------------|
| 1 | Cluster | `bootstrap-kind.sh` or Terraform (EKS) |
| 2 | Policies | `scripts/apply-policies.sh` |
| 3 | Argo CD | `argocd/project-thesis.yaml`, `application-*.yaml`, optional `rbac.yaml` |
| 4 | Monitoring | `monitoring/prometheus/*.yaml`, optional `monitoring/otel/collector-config.yaml` |
| 5 | Evidence / tests | Threat tests `scripts/threat-tests/run-all.sh`; Grafana dashboards (import from `monitoring/grafana/dashboards/`) |

---

*For Layer 1 backend and EKS details see `infra/README.md`. For monitoring apply details see `monitoring/README.md`.*
