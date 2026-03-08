# pipelines/ — Layer 4: Tekton Pipelines + Chains

**Reference:** CHAPTER3_REFERENCE.md §3.2.4 Layer 4, §3.2.3 Layer 3, Table 1 (Tekton, Tekton Chains).

## Path A (Figure 2): Firewall application

Order: **gosec → Kaniko build → Trivy + CycloneDX SBOM → Conftest → cosign sign**. Tekton Chains (when installed) produces in-toto/SLSA attestations.

### Tasks

| Task | Layer 3 / Table 1 | Purpose |
|------|-------------------|--------|
| git-clone | — | Clone repo |
| gosec | §3.2.3, Table 1 | Go static analysis |
| kaniko-build | §3.2.3, Table 1 | Daemonless image build; outputs IMAGE_DIGEST |
| trivy-sbom | §3.2.3, Table 1 | Vulnerability scan + CycloneDX SBOM |
| conftest | §3.2.3, Table 1 | Policy test on manifests (policies/rego) |
| cosign-sign | Table 1 | Sign image (Sigstore) |
| cosign-attest | Table 1 | Optional attestation (Chains covers SLSA) |

### Apply

```bash
kubectl apply -f pipelines/tasks/
kubectl apply -f pipelines/pipelines/
# Optional: Chains config (after installing Tekton Chains)
kubectl apply -f pipelines/chains-config.yaml
```

### Run Path A

Create a PipelineRun with params `REPO_URL`, `REVISION`, `IMAGE` and workspaces `source` (PVC or emptyDir), optional `dockerconfig`, `sbom-output`. Example:

```yaml
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: path-a-firewall-
spec:
  pipelineRef:
    name: path-a-firewall
  params:
    - name: REPO_URL
      value: "https://github.com/your-org/thesis-eac-governance-platform"
    - name: REVISION
      value: "main"
    - name: IMAGE
      value: "641133458487.dkr.ecr.us-east-1.amazonaws.com/thesis-eac/firewall:latest"
  workspaces:
    - name: source
      volumeClaimTemplate:
        spec:
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 1Gi
    - name: dockerconfig
      secret:
        secretName: docker-config  # optional, for ECR push
    - name: sbom-output
      volumeClaimTemplate:
        spec:
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 100Mi
```

## Path B (Figure 3): Governance

Pipeline `path-b-governance`: clone → Conftest on policies/manifests. Use for policy or pipeline changes (with CODEOWNERS).

## Chains (Evidence Plane)

`chains-config.yaml` documents Tekton Chains options (in-toto provenance, SLSA). Install Chains and apply the ConfigMap to `tekton-chains` namespace for signed attestations.
