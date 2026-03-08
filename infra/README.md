# infra/ — Layer 1: Infrastructure Provisioning

**Reference:** CHAPTER3_REFERENCE.md §3.2.1 Layer 1, Table 1 (Terraform).

Terraform provisions: **EKS** (cluster for virtual firewall), **ECR** (immutable image tags), **VPC** (isolated subnets), **IAM** (EKS roles). Uses **S3 backend + DynamoDB locking** (profile `thesis`) per Table 1.

---

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with profile `thesis`
- `terraform-aws-modules/vpc` and `terraform-aws-modules/eks` (via `terraform init`)

---

## First-time setup: Backend

1. **Create S3 bucket and DynamoDB table** (one-time):
   ```bash
   AWS_PROFILE=thesis ./scripts/create-terraform-backend.sh thesis-eac-tfstate us-east-1
   ```
2. **Copy backend config:**
   ```bash
   cp infra/backend.hcl.example infra/backend.hcl
   # Edit backend.hcl if needed: bucket, region (use_lockfile = true uses native S3 locking; no DynamoDB required)
   ```
3. **Init Terraform:**
   ```bash
   cd infra
   terraform init -backend-config=backend.hcl
   ```

---

## Apply

```bash
cd infra
terraform plan -var-file=terraform.tfvars.example   # optional vars
terraform apply
```

**Outputs:** `eks_cluster_name`, `ecr_firewall_repository_url`, `vpc_id` — used by Argo CD, Tekton, and pipelines.

---

## Post-apply Authentication

Terraform creates an **EKS Access Entry** for the IAM user `thesis-admin` with `AmazonEKSClusterAdminPolicy` (cluster scope). This uses the EKS Access Entry method (`authenticationMode = "API_AND_CONFIG_MAP"`) so `kubectl` works without aws-auth ConfigMap.

The resources are defined in `main.tf`:

- `aws_eks_access_entry.thesis_admin` — associates IAM user with cluster
- `aws_eks_access_policy_association.thesis_admin_cluster_admin` — grants cluster admin policy

**Importing existing resources** (if access entry was created manually; `terraform apply` fails with ResourceInUseException):

```bash
cd infra

# Access entry (try slash format first; if that fails, use comma format)
terraform import aws_eks_access_entry.thesis_admin thesis-eac-eks/arn:aws:iam::641133458487:user/thesis-admin

# Policy association
terraform import aws_eks_access_policy_association.thesis_admin_cluster_admin thesis-eac-eks/arn:aws:iam::641133458487:user/thesis-admin/arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy

terraform apply -auto-approve
```

After a successful import, `terraform apply` should show 0 changes or only minor updates.

**Manual fallback** (if access entry was created outside Terraform and import is not used):

```bash
# 1. Create access entry for IAM user thesis-admin
aws eks create-access-entry \
  --cluster-name thesis-eac-eks \
  --principal-arn arn:aws:iam::641133458487:user/thesis-admin \
  --type STANDARD \
  --profile thesis

# 2. Associate AmazonEKSClusterAdminPolicy (cluster scope)
aws eks associate-access-policy \
  --cluster-name thesis-eac-eks \
  --principal-arn arn:aws:iam::641133458487:user/thesis-admin \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --profile thesis

# 3. Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name thesis-eac-eks --profile thesis

# 4. Verify
kubectl get nodes
```

---

## ECR immutability (§3.1, Table 3)

`ecr.tf` sets `image_tag_mutability = "IMMUTABLE"`. Use digest-only refs in manifests; cosign verification enforced at admission (Layer 2).
