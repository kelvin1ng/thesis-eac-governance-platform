# Runbook: Cluster bootstrap

## Scope

EKS cluster creation and initial add-ons (Gatekeeper, Argo CD). Use for net-new or after destroy.

## Prerequisites

- AWS profile `thesis` configured; repo under WSL (`/home/...`).
- `make preflight` passes.

## Steps

1. **Preflight**
   ```bash
   make preflight
   ```

2. **Local prep**
   ```bash
   make prep
   ```

3. **Infrastructure**
   ```bash
   make infra
   ```
   Ensures S3 backend and `infra/backend.hcl` exist; runs Terraform init/plan/apply.

4. **Kubeconfig**
   ```bash
   make kubeconfig
   ```

5. **Add-ons**
   ```bash
   make addons
   ```
   Installs Gatekeeper (memory-tuned) and Argo CD.

6. **Policies**
   ```bash
   make policies
   ```

7. **Argo CD apps**
   ```bash
   make argocd
   ```

8. **Monitoring**
   ```bash
   make monitoring
   ```

## Validation

- `make health`
- `make nodes`
- `make pods`

## References

- DEPLOYMENT-RUNBOOK.md
- environments/dev/cluster.env
