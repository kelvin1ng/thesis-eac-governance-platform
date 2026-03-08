# Runbook: Gatekeeper troubleshooting

## Common issues

### Constraint not enforced

- **Check:** `kubectl get constrainttemplates`, `kubectl get constraints -A`
- **Actions:** Ensure CRD is established: `kubectl wait --for=condition=Established crd/constrainttemplates.templates.gatekeeper.sh`. Re-apply constraints: `./scripts/apply-policies.sh`.
- **Verify:** `kubectl get pods -n gatekeeper-system` (controller Running).

### Admission denial unclear

- **Check:** `kubectl describe constraint <name>`, events on the rejected resource.
- **Actions:** Review ConstraintTemplate and Rego in `policies/`. Test with `conftest test` locally.
- **Verify:** Gatekeeper logs: `kubectl logs -n gatekeeper-system -l control-plane=controller-manager -c manager`

### Controller CrashLoopBackOff

- **Check:** `kubectl get pods -n gatekeeper-system`, `kubectl describe pod -n gatekeeper-system -l control-plane=controller-manager`
- **Actions:** Reduce memory (e.g. `kubectl set resources deployment/gatekeeper-controller-manager -n gatekeeper-system --limits=memory=384Mi`). Check image pull and RBAC.

## Diagnostics

```bash
kubectl get constrainttemplates
kubectl get constraints -A
kubectl get validatingwebhookconfiguration | grep gatekeeper
kubectl logs -n gatekeeper-system -l control-plane=controller-manager -c manager --tail=50
```

## References

- policies/templates/, policies/constraints/
- docs/decisions/0003-use-gatekeeper.md
