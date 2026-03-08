# argocd/ — Layer 4: Argo CD Applications, Projects, RBAC

**Reference:** CHAPTER3_REFERENCE.md §3.2.4 Layer 4, §3.3 Table 2 (Platform-Centric), Table 3.

- **Single-writer principle:** Argo CD is the sole logical writer to cluster state; Tekton does not push to cluster [3.2.4].
- **Drift detection:** Continuous reconciliation; any divergence is drift; self-heal + prune restore declared state.
- **Multi-tenant isolation:** AppProject `thesis` scopes source repos and destinations (Table 3).
- **RBAC:** Restrict who can change Applications; default readonly, grant `role:thesis-admin` for thesis project.

## Resources

| File | Purpose |
|------|---------|
| `project-thesis.yaml` | AppProject: allowed repos, destinations (firewall, default, gatekeeper-system) |
| `application-firewall.yaml` | Path A: firewall Helm app; auto-sync, prune, selfHeal; digest via values |
| `application-policies.yaml` | Path B: policies (Gatekeeper) from Git; optional |
| `rbac.yaml` | ConfigMap argocd-rbac-cm: policy.default=readonly, policy.csv for thesis-admin |

## Apply

**Prerequisite:** Argo CD installed (e.g. `scripts/bootstrap-kind.sh`).

1. **Set repo URL** in Application manifests (replace `your-org` / repo URL):
   ```bash
   # application-firewall.yaml and application-policies.yaml: spec.source.repoURL
   ```
2. **Apply project and applications:**
   ```bash
   kubectl apply -f argocd/project-thesis.yaml
   kubectl apply -f argocd/application-firewall.yaml
   kubectl apply -f argocd/application-policies.yaml
   ```
3. **RBAC:** Merge `argocd/rbac.yaml` into existing `argocd-rbac-cm` or apply in greenfield:
   ```bash
   kubectl apply -f argocd/rbac.yaml
   ```
   If Argo CD already has argocd-rbac-cm, patch or replace with merged content.

## Digest-only (Layer 2)

Pipeline (Path A) outputs `IMAGE_DIGEST`. To deploy by digest:

- Commit a values override (e.g. `apps/firewall/helm/values-production.yaml`) with `image.digest: sha256:...` and point the Application `valueFiles` at it, or
- Use Helm parameters in Application: `helm.parameters[].name: image.digest`, value from pipeline (e.g. via Git commit from CI).

## Auto-sync

Both Applications use `syncPolicy.automated: { prune: true, selfHeal: true }` for drift detection and automatic revert (Table 1, §3.2.4).
