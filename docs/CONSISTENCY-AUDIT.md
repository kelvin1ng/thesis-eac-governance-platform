# Consistency and Discrepancy Audit

**Scope:** Full codebase alignment between documentation, Kubernetes manifests, alert rules, Grafana dashboards, threat tests, Argo CD, Gatekeeper, and monitoring stack.  
**Reference:** CHAPTER3_REFERENCE.md, PROJECT_PLAN.md, Table 1 / Table 3.

---

## 1. Issue list

### BLOCKER

| ID | File + line | Issue | Fix applied |
|----|-------------|--------|-------------|
| B1 | `monitoring/prometheus/alerts.yaml` L25 | Alert `ArgoCDAppSyncFailed` uses metric `argocd_app_health_status{health_status="Degraded"}`. Argo CD exposes **health_status as a label on `argocd_app_info`**, not a separate metric. Alert would never fire. | Changed to `argocd_app_info{health_status="Degraded"} == 1`. |
| B2 | `argocd/project-thesis.yaml` sourceRepos | Application `application-firewall.yaml` uses `repoURL: https://github.com/kelvin-ng/thesis-eac-governance-platform.git`. Project allowed only `thesis-eac-governance-platform/*` and `*.github.com/*/thesis-eac-governance-platform*`; host `github.com` (no subdomain) may not match second pattern. App would be rejected by Project. | Added `https://github.com/kelvin-ng/thesis-eac-governance-platform*` to sourceRepos so deployed app matches. |
| B3 | `scripts/threat-tests/4-direct-kubectl.sh` L23–24 | Script tries deployment names `firewall` and `thesis-eac-firewall`. Helm chart fullname is `{{ .Release.Name }}-{{ .Chart.Name }}` → `firewall-firewall` when Argo CD installs with release name `firewall`. Actual deployment name is `firewall-firewall`. | Added `firewall-firewall` to the list of names to try (first). |

### MAJOR

| ID | File + line | Issue | Fix applied |
|----|-------------|--------|-------------|
| M1 | `monitoring/prometheus/gatekeeper-podmonitor.yaml` L7 | Label `release: kps` does not match kube-prometheus-stack’s selector (`release: kube-prometheus-stack`). Prometheus would not select this PodMonitor. | Changed to `release: kube-prometheus-stack`. Added CHAPTER3 comment. |
| M2 | `monitoring/README.md` L90 | ArgoCDAppSyncFailed described as "Sync failed for **10m**"; actual rule uses `for: 2m`. | Corrected table to "for 2m". |
| M3 | `monitoring/README.md` Layout | Layout lists only `alerts.yaml` and `servicemonitor-gatekeeper.yaml`; repo also has `gatekeeper-podmonitor.yaml`. | Added `gatekeeper-podmonitor.yaml` to layout and apply steps (optional alternative to ServiceMonitor). |
| M4 | `scripts/threat-tests/5-policy-bypass.sh` L46–51 | Uses fixed path `/tmp/threat5-out.txt`; on Windows (e.g. Git Bash) `$TMPDIR` may differ or `/tmp` may not be preferred. | Use `${TMPDIR:-/tmp}` for portable temp path. |

### MINOR

| ID | File + line | Issue | Fix applied |
|----|-------------|--------|-------------|
| N1 | `monitoring/README.md` vs `DEPLOYMENT.md` | DEPLOYMENT step 5 says "Prometheus rules + Gatekeeper ServiceMonitor"; does not mention PodMonitor. | DEPLOYMENT.md already says `monitoring/prometheus/*.yaml` (applies all); monitoring/README now documents PodMonitor. No change to DEPLOYMENT. |
| N2 | Gatekeeper metric names | Official Gatekeeper v3 docs use `gatekeeper_violations` (audit); some setups expose `gatekeeper_constraint_violations_total`. Alerts/dashboards use `gatekeeper_constraint_violations_total`. | No code change. Validation Runbook includes fallback PromQL using `gatekeeper_violations` if no data. |
| N3 | Grafana datasource variable | Dashboards use `query: "prometheus"` and `${datasource}`; after import user must set variable to the Prometheus datasource UID. | Documented in monitoring/README and Validation Runbook. No change. |
| N4 | Argo CD alert `$labels.namespace` | Alert description says "namespace {{ $labels.namespace }}"; for Argo CD this is the namespace of the Application CR (argocd), not destination. | Left as-is; acceptable for "which app". No change. |

---

## 2. Cross-cutting consistency checks (verified)

- **Alerts ↔ Dashboards:** Both use `argocd_app_info`, `argocd_app_sync_total`, `gatekeeper_constraint_violations_total`; aligned.
- **Alerts ↔ PrometheusRule:** Rule is in namespace `monitoring`, labels `prometheus: kube-prometheus-stack`; matches typical kube-prometheus-stack rule selector.
- **ServiceMonitor vs PodMonitor:** Both target Gatekeeper controller; ServiceMonitor uses port name `metrics`, namespace `gatekeeper-system`, labels `control-plane: controller-manager`, `gatekeeper.sh/system: "yes"`. PodMonitor now uses `release: kube-prometheus-stack`; same namespace/selector. Gatekeeper exposes metrics on port 8888 by default; service must expose a port named `metrics` for ServiceMonitor (or use PodMonitor).
- **Threat tests ↔ resources:** Threat 1 checks `.github/BRANCH-PROTECTION.md`, `pr-checks.yaml`, Argo CD apps. Threat 2 checks CODEOWNERS paths (root and .github). Threat 3 checks `policies/constraints/allowlist.yaml`, cosign, pipeline trivy/cosign. Threat 4 now checks deployment names `firewall-firewall`, `firewall`, `thesis-eac-firewall`. Threat 5 applies Deployment in `default` without required labels (K8sRequiredLabels matches default). All aligned.
- **Firewall app:** Helm chart name `firewall`, release name from Argo CD = Application name `firewall` → fullname `firewall-firewall`; deployment in namespace `firewall`. Threat 4 and FirewallPodNotReady alert use namespace `firewall`; consistent.
- **Policies:** labels constraint excludes `argocd`, `gatekeeper-system`, etc.; does not exclude `default`, so threat 5 denial in default is expected. Consistent.

---

## 3. Fixes applied (BLOCKER + MAJOR)

- **B1:** `monitoring/prometheus/alerts.yaml` — ArgoCDAppSyncFailed expr now uses `argocd_app_info{health_status="Degraded"} == 1` (and existing `argocd_app_sync_total{phase="Failed"} > 0`).
- **B2:** `argocd/project-thesis.yaml` — sourceRepos extended with `https://github.com/kelvin-ng/thesis-eac-governance-platform*`.
- **B3:** `scripts/threat-tests/4-direct-kubectl.sh` — deployment name list now includes `firewall-firewall` first, then `firewall`, `thesis-eac-firewall`.
- **M1:** `monitoring/prometheus/gatekeeper-podmonitor.yaml` — label set to `release: kube-prometheus-stack`; added header comment.
- **M2:** `monitoring/README.md` — Alert summary table: ArgoCDAppSyncFailed "for 10m" → "for 2m".
- **M3:** `monitoring/README.md` — Layout and apply steps updated to include `gatekeeper-podmonitor.yaml`.
- **M4:** `scripts/threat-tests/5-policy-bypass.sh` — temp file uses `THREAT5_OUT="${TMPDIR:-/tmp}/threat5-out.txt"` and cleanup.

---

## 4. Validation Runbook

Use these commands to verify the monitoring and evidence plane end-to-end after applying the audit fixes.

### 4.1 Prerequisites

- Cluster with kube-prometheus-stack, Argo CD, Gatekeeper installed (e.g. `./scripts/bootstrap-kind.sh`).
- Policies applied: `./scripts/apply-policies.sh`.
- Argo CD Project and Applications applied; firewall app synced to namespace `firewall`.

### 4.2 Prometheus targets

```bash
# Port-forward Prometheus (adjust namespace/service if different)
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090

# In another terminal: check ServiceMonitor/PodMonitor are discovered (targets up)
# Open http://localhost:9090/targets and confirm:
# - prometheus-operatorservicemonitor/gatekeeper-system-gatekeeper-* (or similar) is UP
# - prometheus-operatorpodmonitor/monitoring-gatekeeper-* (or similar) is UP if PodMonitor applied
```

Or via Prometheus config:

```bash
kubectl get servicemonitor -n gatekeeper-system gatekeeper -o yaml
kubectl get podmonitor -n monitoring gatekeeper-controller-manager -o yaml
```

### 4.3 Key PromQL queries (return data when stack is healthy)

Run at http://localhost:9090/graph (or equivalent):

```promql
# Argo CD: apps and sync status (requires Argo CD metrics)
argocd_app_info
argocd_app_info{sync_status="OutOfSync"}
count(argocd_app_info{sync_status="OutOfSync"})

# Argo CD: sync operations
argocd_app_sync_total

# Gatekeeper: violations (primary; Gatekeeper v3 may use gatekeeper_violations instead)
gatekeeper_constraint_violations_total
# Fallback if no series:
gatekeeper_violations

# Gatekeeper: audit last run
gatekeeper_audit_last_run_time

# Firewall workload: ready pods in firewall namespace
kube_pod_status_ready{namespace="firewall", condition="true"}
count(kube_pod_status_ready{namespace="firewall", condition="true"} == 1)
```

If Gatekeeper metrics are missing, ensure Gatekeeper controller exposes metrics (port 8888) and that ServiceMonitor/PodMonitor select the correct labels and namespace (`gatekeeper-system`).

### 4.4 Grafana dashboards

1. Import dashboards from `monitoring/grafana/dashboards/`:
   - `argocd-sync.json`
   - `gatekeeper-audit.json`
2. Set the **datasource** variable to the cluster’s Prometheus datasource (e.g. the one created by kube-prometheus-stack).
3. Confirm panels show data:
   - **Argo CD Sync:** table and stat for `argocd_app_info`; timeseries for `argocd_app_sync_total`.
   - **Gatekeeper Audit:** table/stat/timeseries for `gatekeeper_constraint_violations_total` (or `gatekeeper_violations` if that’s what’s exposed).

### 4.5 Threat tests (run cleanly)

From repo root (WSL or Git Bash on Windows, LF line endings):

```bash
./scripts/threat-tests/run-all.sh
```

Expected:

- **Threat 1:** [OK] for BRANCH-PROTECTION.md, pr-checks.yaml; [OK] or [SKIP] for Argo CD.
- **Threat 2:** [OK] CODEOWNERS and path-b workflow.
- **Threat 3:** [OK] allowlist/cosign/trivy; [OK] or [SKIP] for cluster denial.
- **Threat 4:** [OK] label removed by self-heal (requires firewall app synced; deployment name `firewall-firewall` or `firewall`).
- **Threat 5:** [OK] Gatekeeper denied deployment (or [WARN] if constraint not matching).

If threat 4 reports [SKIP], ensure namespace `firewall` exists and deployment exists (name `firewall-firewall` when using Helm from Argo CD with release name `firewall`).

---

*Audit completed; BLOCKER and MAJOR fixes applied. Re-run this runbook after any change to monitoring or threat tests.*
