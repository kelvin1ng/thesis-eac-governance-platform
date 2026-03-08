# CHAPTER3_REFERENCE.md §3.2.1 Layer 1: outputs for Argo CD, Tekton, pipelines
# EKS kubeconfig, ECR URL for digest-only image pushes; Table 1 evidence linkage.

output "eks_cluster_name" {
  description = "EKS cluster name for kubectl/Argo CD"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "eks_cluster_certificate_authority_data" {
  description = "EKS cluster CA cert (for kubeconfig)"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "ecr_firewall_repository_url" {
  description = "ECR repository URL for firewall image (use digest, not tag per §3.1)"
  value       = aws_ecr_repository.firewall.repository_url
}

output "vpc_id" {
  description = "VPC ID for network policy linkage"
  value       = module.vpc.vpc_id
}
