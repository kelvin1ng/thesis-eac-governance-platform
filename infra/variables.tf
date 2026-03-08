# CHAPTER3_REFERENCE.md §3.2.1 Layer 1: Infrastructure variables
# Tagging for downstream policy linkage; compliance scope per architecture.

variable "account_id" {
  description = "AWS account ID (for EKS access entry principal ARNs)"
  type        = string
  default     = "641133458487"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "node_instance_type" {
  description = "Instance type for EKS managed node group. t3.micro invalid: maxPods=4 + prefix delegation makes cluster unschedulable beyond system pods."
  type        = string
  default     = "t3.medium"
}

variable "aws_region" {
  description = "AWS region (CHAPTER3: tagging for policy enforcement linkage); use region instead"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming (thesis-eac-governance-platform)"
  type        = string
  default     = "thesis-eac"
}

variable "environment" {
  description = "Environment: dev, staging, prod (CHAPTER3: compliance scope tagging)"
  type        = string
  default     = "dev"
}

variable "compliance_scope" {
  description = "Compliance scope tag for downstream policy engines (CHAPTER3 §3.2.1)"
  type        = string
  default     = "eac-governance"
}

variable "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "eks_node_instance_types" {
  description = "EKS node group instance types (legacy; prefer node_instance_type)"
  type        = list(string)
  default     = ["t3.micro"]
}
