# CHAPTER3_REFERENCE.md §3.2.1 Layer 1: Infrastructure Provisioning, the Foundation
# EKS, VPC, IAM; provider-agnostic modular structure; tagging for policy linkage [37].
# Table 1: Terraform — Execution Plane with governance gates.

# --- Provider (profile "thesis" per PROJECT_PLAN) ---
provider "aws" {
  region  = var.region
  profile = "thesis"

  default_tags {
    tags = {
      Project        = var.project_name
      Environment    = var.environment
      ComplianceScope = var.compliance_scope
      ManagedBy      = "terraform"
    }
  }
}

# --- VPC (CHAPTER3: isolated subnets, baseline networking) ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true # Cost optimization for thesis/dev
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

# --- EKS (CHAPTER3: cluster hosting virtual firewall; Table 1 Execution Plane) ---
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.project_name}-eks"
  cluster_version = var.eks_cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    instance_types = [var.node_instance_type]
  }
  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }
}

# --- EKS Access Entry (kubectl auth via API_AND_CONFIG_MAP; reproducible) ---
resource "aws_eks_access_entry" "thesis_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::${var.account_id}:user/thesis-admin"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "thesis_admin_cluster_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::${var.account_id}:user/thesis-admin"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}
