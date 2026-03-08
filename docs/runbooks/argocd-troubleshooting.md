# Runbook: Argo CD troubleshooting

## Common issues

### Application stuck OutOfSync

- **Check:** `kubectl get applications -n argocd`
- **Actions:** Sync in UI or `argocd app sync <name>`. Ensure `sourceRepos` in AppProject includes your repo URL.
- **Verify:** `kubectl get appproject thesis -n argocd -o yaml`

### Application not found / sync failed

- **Check:** `kubectl describe application <name> -n argocd`
- **Actions:** Fix repo URL, path, or branch in Application spec. Ensure Git repo is reachable (token/SSH if private).
- **Verify:** Argo CD server logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server`

### Project denies repo

- **Check:** AppProject `sourceRepos` and Application `spec.source.repoURL` must match (pattern).
- **Actions:** Add repo pattern to `argocd/project-thesis.yaml` and re-apply.

## Diagnostics

```bash
kubectl get applications -n argocd
kubectl get pods -n argocd
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=100
```

## References

- argocd/project-thesis.yaml, application-firewall.yaml
- docs/decisions/0002-use-argocd.md
