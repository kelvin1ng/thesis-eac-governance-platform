# Runbook: Destroy and cleanup

## Scope

Tear down EKS and related infrastructure; remove local kubeconfig context.

## Prerequisites

- Confirmation that no production workloads depend on this cluster.
- AWS profile `thesis` and Terraform state (S3 backend) accessible.

## Steps

1. **Optional: collect evidence**
   ```bash
   make collect-evidence
   ```

2. **Destroy**
   ```bash
   make destroy
   ```
   Script prompts: type `DESTROY` to continue. Runs `terraform destroy -auto-approve` in `infra/`, then deletes kubeconfig context for thesis-eac-eks.

3. **Verify**
   ```bash
   aws eks list-clusters --region us-east-1 --profile thesis
   ```
   Cluster should no longer appear (or show DELETING).

## Manual cleanup (if needed)

- Delete any orphaned ECR images or S3 objects if Terraform did not remove them.
- Remove `~/.kube/config` entry for the cluster if delete-context failed.
- Clear `.deploy-state` in repo root if re-deploying from scratch: `make --directory=. preflight` then `run-all-phases.sh --reset` or `make deploy`.

## References

- scripts/ops/destroy-cluster.sh
- infra/README.md
