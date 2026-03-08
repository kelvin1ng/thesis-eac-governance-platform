# policies/ — Layer 2: Policy Enforcement (Gatekeeper + Rego)

**Reference:** CHAPTER3_REFERENCE.md §3.2.2 Layer 2, Table 1 (OPA, Gatekeeper).

Three policy categories per §3.2.2:

1. **Image registry allowlist + signature verification** — images from trusted registries; digest-only (sha256:) for integrity; cosign in pipeline
2. **Traceability labels** — `owner`, `environment`, `compliance-scope`
3. **Firewall networking** — no privileged, no hostNetwork, capabilities limited to NET_RAW/NET_ADMIN for packet inspection

---

## Structure

| Path | Purpose |
|------|---------|
| `templates/` | ConstraintTemplates (Rego + CRD schema) |
| `constraints/` | Constraint instances (parameters, match) |
| `rego/` | Rego libs for Conftest (CI validation) |

---

## Apply to cluster

**Prerequisites:** Gatekeeper installed (e.g. via `scripts/bootstrap-kind.sh`).

```bash
# Apply templates first (creates CRDs), then constraints
kubectl apply -f policies/templates/
kubectl wait --for=condition=Established crd/constrainttemplates.templates.gatekeeper.sh --timeout=60s
kubectl apply -f policies/constraints/
```

Or with Kustomize:
```bash
kubectl apply -k policies/
```

---

## Conftest (CI)

Validate manifests before apply:
```bash
conftest test apps/firewall/helm/templates/deployment.yaml -p policies/rego/
```

---

## Local / Kind registry

For local dev with Kind, add your registry to `constraints/allowlist.yaml`:
```yaml
registries:
  - "localhost:5000"
  - "641133458487.dkr.ecr.us-east-1.amazonaws.com"
```
