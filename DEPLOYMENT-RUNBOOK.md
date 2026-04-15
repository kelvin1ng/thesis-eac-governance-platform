# EKS Deployment Runbook — Full Restore from Scratch

**Purpose:** After `terraform destroy`, restore the entire thesis-eac-governance-platform environment on EKS (worker nodes t3.medium). All commands are to be run from **WSL (Ubuntu on Windows)**.

**Reference:** PROJECT_PLAN.md, DEPLOYMENT.md, infra/README.md, monitoring/README.md, docs/CONSISTENCY-AUDIT.md.

---

## 1. Prerequisites (WSL-specific)

### 1.1 Required CLIs and minimum versions

| CLI        | Minimum version | Check command |
|-----------|-----------------|---------------|
| aws       | 2.x             | `aws --version` |
| terraform | 1.0+            | `terraform version` |
| kubectl   | 1.27+           | `kubectl version --client` |
| helm      | 3.x             | `helm version` |
| jq        | 1.6+            | `jq --version` |
| git       | 2.x             | `git --version` |
| dos2unix  | 7.x             | `dos2unix --version` |

### 1.2 AWS auth from WSL (profile `thesis`)

- Configure AWS CLI so profile `thesis` is available (e.g. `~/.aws/credentials` and `~/.aws/config` in WSL).
- Use WSL’s Linux filesystem for credentials; avoid referencing `/mnt/c/` for AWS config if it causes permission or path issues.

### 1.3 Kubeconfig location

- EKS will write kubeconfig to **`~/.kube/config`** in WSL when you run `aws eks update-kubeconfig`.
- Ensure no `KUBECONFIG` override points at a Windows path unless intended.

### 1.4 Windows ↔ WSL filesystem

- **Run all commands from the repo cloned inside WSL** (e.g. `~/projects/thesis-eac-governance-platform` or `/home/<user>/...`).
- Avoid running Terraform or shell scripts from a path under `/mnt/c/`; line endings and script execution can fail.
- If the repo is on Windows (e.g. `C:\Projects\...`), clone a fresh copy in WSL or use `cd /mnt/c/Projects/thesis-eac-governance-platform` only when necessary and fix line endings (see below).

### 1.5 Line endings (LF) for shell scripts

- All repo shell scripts must use **LF** (Unix) line endings.
- If you cloned in Windows or see `\r` errors when running scripts:
  ```bash
  find . -name '*.sh' -exec dos2unix {} \;
  ```
- Repo root should have `.gitattributes` enforcing LF for `*.sh`.

---

## 2. Phase 0 — Local prep (WSL)

**Run from:** WSL home or project directory. Clone repo into WSL if not already.

### 2.1 Verify tools and line endings

```bash
aws --version
terraform version
kubectl version --client
helm version
jq --version
git --version
dos2unix --version
```

**Success:** All commands print a version.

**Failure:** Install missing tools (e.g. `sudo apt install awscli terraform kubectl helm jq git dos2unix` or use official installers).

```bash
cd ~/path/to/thesis-eac-governance-platform
find . -name '*.sh' -exec dos2unix {} \;
```

### 2.2 AWS auth verification

```bash
export AWS_PROFILE=thesis
aws sts get-caller-identity
```

**Success:** JSON with `Account`, `UserId`, `Arn` for the thesis profile.

**Failure:** `aws configure --profile thesis` or fix credentials; ensure profile name is `thesis`.

### 2.3 Export profile for remainder of runbook

```bash
export AWS_PROFILE=thesis
```

Use this in the same shell (or add to your shell profile for the session).

---

## 3. Phase 1 — Terraform (EKS rebuild)

**Run from:** Repo root, then `infra/`.

### 3.1 Backend (one-time; skip if bucket and table already exist)

```bash
cd "$(git rev-parse --show-toplevel)"
AWS_PROFILE=thesis ./scripts/create-terraform-backend.sh thesis-eac-tfstate us-east-1
```

**Success:** Script reports S3 bucket and DynamoDB table created or already present.

Copy backend config (if not already done):

```bash
cp infra/backend.hcl.example infra/backend.hcl
# Edit infra/backend.hcl if bucket/region/table differ (defaults: thesis-eac-tfstate, us-east-1, thesis-eac-tfstate-lock)
```

### 3.2 Terraform init, plan, apply

```bash
cd infra
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -auto-approve
```

**Success:** `Apply complete!` and outputs (e.g. `eks_cluster_name`, `ecr_firewall_repository_url`).

**Failure:**  
- Backend: confirm S3 bucket and DynamoDB table exist; `backend.hcl` matches.  
- EKS/Access Entry: see infra/README.md for `terraform import` and manual access-entry steps.

---

## 4. Phase 2 — Kubeconfig and cluster sanity

**Run from:** Any; kubeconfig is written to `~/.kube/config`.

```bash
aws eks update-kubeconfig --region us-east-1 --name thesis-eac-eks --profile thesis
kubectl cluster-info
kubectl get nodes
```

**Success:** Cluster endpoint resolves; nodes show `Ready` (e.g. 2–3 t3.medium nodes).

**Failure:**  
- `Unable to connect`: check IAM access entry for `thesis-admin` (or your user); see infra/README.md.  
- Nodes NotReady: wait 2–3 minutes; `kubectl describe node` for conditions.

---

## 5. Phase 3 — Core add-ons

**Run from:** Repo root.

### 5.1 Gatekeeper (with reduced memory for small nodes)

```bash
cd "$(git rev-parse --show-toplevel)"
kubectl create namespace gatekeeper-system --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.15/deploy/gatekeeper.yaml"
kubectl wait --for=condition=Available deployment/gatekeeper-controller-manager -n gatekeeper-system --timeout=300s
```

Optional: reduce controller memory for t3.medium/small-node compatibility:

```bash
kubectl set resources deployment/gatekeeper-controller-manager -n gatekeeper-system \
  --limits=memory=384Mi --requests=memory=128Mi
kubectl rollout status deployment/gatekeeper-controller-manager -n gatekeeper-system
```

**Success:** `deployment.apps/gatekeeper-controller-manager condition met`; pods in `gatekeeper-system` Running.

**Failure:**  
- Image pull: check node IAM for ECR (or use public Gatekeeper image).  
- CrashLoopBackOff: increase memory or check logs: `kubectl logs -n gatekeeper-system -l control-plane=controller-manager -c manager`.

### 5.2 Argo CD

```bash
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s
```

**Success:** `deployment.apps/argocd-server condition met`; pods in `argocd` Running.

**Failure:**  
- Resource limits: if nodes are small, consider reducing Argo CD component resources or increasing node size.

---

## 6. Phase 4 — Gatekeeper policies

**Run from:** Repo root. Uses `scripts/apply-policies.sh` and repo paths under `policies/`.

```bash
cd "$(git rev-parse --show-toplevel)"
./scripts/apply-policies.sh
```

**Success:** Script prints "Applying ConstraintTemplates...", "Applying Constraints...", "Done."

Verify:

```bash
kubectl get constrainttemplates
kubectl get constraints -A
kubectl get validatingwebhookconfiguration | grep gatekeeper
```

**Success:** ConstraintTemplates and Constraints listed; Gatekeeper webhook present.

**Failure:**  
- CRD not established: `kubectl wait --for=condition=Established crd/constrainttemplates.templates.gatekeeper.sh --timeout=120s` then re-run `./scripts/apply-policies.sh`.  
- Webhook not ready: wait for Gatekeeper controller to be Ready, then re-apply constraints.

---

## 7. Phase 5 — Argo CD applications

**Run from:** Repo root.

### 7.1 Update repoURL (if different from default)

Applications point at the Git repo. If your fork or org differs, set the repo URL (example for current repo):

```bash
cd "$(git rev-parse --show-toplevel)"
# Optional: sed to replace repoURL in application-*.yaml, or edit manually
# Example for kelvin-ng repo (already in repo):
# grep -l repoURL argocd/application-*.yaml
```

Repo already contains `repoURL: https://github.com/kelvin-ng/thesis-eac-governance-platform.git` in `argocd/application-firewall.yaml`; project `thesis` allows it. Change only if your repo URL differs.

### 7.2 Apply project, applications, RBAC

```bash
kubectl apply -f argocd/project-thesis.yaml
kubectl apply -f argocd/application-firewall.yaml
kubectl apply -f argocd/application-policies.yaml
kubectl apply -f argocd/rbac.yaml
```

**Success:** `appproject.argoproj.io/thesis configured`, `application.argoproj.io/firewall created` (or configured), same for policies and RBAC.

**Failure:**  
- Project sync error: confirm `sourceRepos` in `argocd/project-thesis.yaml` includes your repo URL pattern.  
- App not syncing: In Argo CD UI or CLI, check Application sync status and events; fix repo URL, path, or branch.

Wait for firewall app to sync (creates namespace `firewall` and deployment):

```bash
kubectl get applications -n argocd
kubectl get ns firewall
# When Synced:
kubectl get deployment -n firewall
```

---

## 8. Phase 6 — Monitoring / Observability

**Run from:** Repo root. Install stack with release name **kps**; then apply repo customizations.

### 8.1 Install kube-prometheus-stack (release name `kps`)

```bash
cd "$(git rev-parse --show-toplevel)"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin \
  --wait --timeout 300s
```

**Success:** `Release "kps" has been installed` or upgraded; pods in `monitoring` (Prometheus, Grafana, etc.) become Ready.

**Failure:**  
- Timeout: increase `--timeout` or check `kubectl get pods -n monitoring` and events.  
- Resource limits: on small nodes, consider reducing Prometheus/Grafana memory in helm `--set` values.

### 8.2 Apply custom PrometheusRule and Gatekeeper monitors

Repo manifests use label `release: kube-prometheus-stack`. Because you installed with release **kps**, add label `release=kps` so Prometheus selects them:

```bash
kubectl apply -f monitoring/prometheus/alerts.yaml
kubectl apply -f monitoring/prometheus/servicemonitor-gatekeeper.yaml
kubectl apply -f monitoring/prometheus/gatekeeper-podmonitor.yaml
# Match release name kps (so Prometheus Operator selects these)
kubectl label prometheusrule thesis-eac-alerts -n monitoring release=kps --overwrite
kubectl label servicemonitor gatekeeper -n gatekeeper-system release=kps --overwrite
kubectl label podmonitor gatekeeper-controller-manager -n monitoring release=kps --overwrite
```

**Success:** Resources created/configured; no errors.

**Failure:**  
- ServiceMonitor not selected: confirm Gatekeeper Service in `gatekeeper-system` has a port named `metrics` (or use only PodMonitor).  
- Alerts not showing: in Prometheus UI, check Configuration → Rules; thesis-eac-alerts should appear.

### 8.3 Grafana: import JSON dashboards

Discover Grafana service name (release `kps`; chart may name it `kps-kube-prometheus-stack-grafana` or similar):

```bash
kubectl get svc -n monitoring | grep -i grafana
```

Port-forward (run in background or second terminal; replace `SVC_NAME` with the Grafana service from above):

```bash
kubectl port-forward svc/SVC_NAME -n monitoring 3000:80
# Example: kubectl port-forward svc/kps-kube-prometheus-stack-grafana -n monitoring 3000:80
```

- Open **http://localhost:3000** in WSL browser or Windows browser (localhost is shared). Login: **admin** / **admin**.
- Import dashboards from repo:
  - **Argo CD Sync:** Upload JSON from `monitoring/grafana/dashboards/argocd-sync.json`.
  - **Gatekeeper Audit:** Upload JSON from `monitoring/grafana/dashboards/gatekeeper-audit.json`.
- For each dashboard, set the **datasource** variable to the Prometheus datasource (e.g. `Prometheus` or the one created by the stack).

**Success:** Dashboards load; after data flows, panels show series (not only "No data").

---

## 9. Phase 7 — Full verification

**Run from:** Repo root. Assumes port-forwards or ingress for Prometheus and Grafana.

### 9.1 Prometheus targets

```bash
# Discover Prometheus service name (e.g. kps-kube-prometheus-stack-prometheus)
kubectl get svc -n monitoring | grep -i prometheus
kubectl port-forward svc/SVC_NAME -n monitoring 9090:9090
# Example: kubectl port-forward svc/kps-kube-prometheus-stack-prometheus -n monitoring 9090:9090
```

Open **http://localhost:9090/targets**. Confirm:

- Targets for Gatekeeper (ServiceMonitor and/or PodMonitor) are **UP**.
- No critical targets Down.

**Failure:**  
- Gatekeeper targets down: check ServiceMonitor/PodMonitor labels (`release=kps`), namespace `gatekeeper-system`, and that Gatekeeper exposes metrics on port 8888.

### 9.2 Key PromQL queries

In Prometheus → Graph (http://localhost:9090/graph), run:

```promql
# Gatekeeper admission denials (v3 may use gatekeeper_validation_request_count or _total suffix)
gatekeeper_validation_request_count_total{admission_status="deny"}
# Or:
gatekeeper_validation_request_count{admission_status="deny"}

# Argo CD sync status and drift
argocd_app_info
argocd_app_info{sync_status="OutOfSync"}
count(argocd_app_info{sync_status="OutOfSync"})

# Firewall workload readiness
kube_pod_status_ready{namespace="firewall", condition="true"}
count(kube_pod_status_ready{namespace="firewall", condition="true"} == 1)
```

**Success:** Queries return series (or empty vector if no denials/OutOfSync); firewall shows 1+ ready when app is deployed.

**Failure:**  
- No Argo CD metrics: ensure Argo CD metrics sidecar or metrics service is scraped by Prometheus (stack may scrape it by default).  
- No Gatekeeper metrics: confirm Gatekeeper version exposes Prometheus metrics and ServiceMonitor/PodMonitor are selected.

### 9.3 Grafana dashboards show data

- Open Argo CD Sync and Gatekeeper Audit dashboards.
- **Success:** Panels show data (e.g. app list, sync status, violations or zero).
- **Failure:** "No data" usually means Prometheus datasource not set, or no series for the time range; run the PromQL above and extend time range.

### 9.4 Threat tests run cleanly

```bash
cd "$(git rev-parse --show-toplevel)"
./scripts/threat-tests/run-all.sh
```

**Success:**  
- Threat 1: [OK] BRANCH-PROTECTION, pr-checks; [OK] or [SKIP] for Argo CD.  
- Threat 2: [OK] CODEOWNERS.  
- Threat 3: [OK] allowlist/cosign/trivy; [OK] or [SKIP] cluster denial.  
- Threat 4: [OK] label removed by self-heal (firewall app synced; deployment `firewall-firewall` or `firewall`).  
- Threat 5: [OK] Gatekeeper denied deployment (or [WARN] if constraint scope differs).

**Failure:**  
- Threat 4 [SKIP]: ensure `firewall` namespace exists and deployment is present (`kubectl get deploy -n firewall`).  
- Threat 5 accepted: check K8sRequiredLabels constraint and that it matches `default` namespace; re-run after policies applied.

---

## 10. Phase 8 — Threat tests and evidence capture

**Run from:** Repo root.

### 10.1 Run threat tests and capture output

```bash
cd "$(git rev-parse --show-toplevel)"
./scripts/threat-tests/run-all.sh 2>&1 | tee threat-tests-$(date +%Y%m%d-%H%M%S).log
```

**Success:** Log file contains full output; expected violations (e.g. Threat 5 denial) and [OK]/[SKIP] as above.

### 10.2 Evidence capture (Chapter 4)

- **Grafana:** Screenshot Argo CD Sync and Gatekeeper Audit dashboards with data.
- **Prometheus:** Screenshot or note PromQL results for `gatekeeper_validation_request_count_total{admission_status="deny"}`, `argocd_app_info`, and firewall readiness.
- **Threat tests:** Save the log file and any screenshots of terminal output.

Store under `docs/ch4-screenshots/` or as specified in docs/CHAPTER4-EVIDENCE.md.

---

## Quick reference — command order

| Phase | Commands (from repo root unless noted) |
|-------|----------------------------------------|
| 0 | `export AWS_PROFILE=thesis`, `aws sts get-caller-identity`, `dos2unix` scripts |
| 1 | `./scripts/create-terraform-backend.sh ...`, `cd infra`, `terraform init -backend-config=backend.hcl`, `terraform apply -auto-approve` |
| 2 | `aws eks update-kubeconfig --region us-east-1 --name thesis-eac-eks --profile thesis`, `kubectl get nodes` |
| 3 | Gatekeeper: `kubectl apply -f https://raw.githubusercontent.com/.../gatekeeper.yaml`; optional resource patch; Argo CD: `kubectl apply -n argocd -f https://raw.githubusercontent.com/.../install.yaml` |
| 4 | `./scripts/apply-policies.sh` |
| 5 | `kubectl apply -f argocd/project-thesis.yaml`, `application-firewall.yaml`, `application-policies.yaml`, `rbac.yaml` |
| 6 | `helm upgrade --install kps prometheus-community/kube-prometheus-stack ...`; apply `monitoring/prometheus/*.yaml`; label with `release=kps`; import Grafana JSON from `monitoring/grafana/dashboards/` |
| 7 | Port-forward Prometheus 9090, Grafana 3000; run PromQL; run `./scripts/threat-tests/run-all.sh` |
| 8 | `./scripts/threat-tests/run-all.sh 2>&1 \| tee ...`; capture screenshots and logs |

---

*All paths and commands are derived from infra/, monitoring/, argocd/, policies/, scripts/, README.md, and DEPLOYMENT.md. For EKS access entry issues, see infra/README.md.*
