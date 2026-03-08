# ADR 0001: Use Amazon EKS for Kubernetes

## Status

Accepted.

## Context

The platform requires a managed Kubernetes control plane for running the virtual firewall workload, Argo CD, Gatekeeper, and monitoring. Self-managed (e.g. kubeadm) increases operational burden; we need a stable, widely supported option suitable for thesis validation and potential production use.

## Decision

Use **Amazon EKS** as the Kubernetes cluster provider. Provision with Terraform (terraform-aws-modules/eks). Use managed node groups (e.g. t3.medium); S3 + DynamoDB (or use_lockfile) for Terraform state; EKS Access Entry for auth.

## Consequences

- Platform is AWS-coupled for infra; app and policy layers remain portable.
- EKS costs (control plane + nodes) apply; NAT gateway adds ~$30/mo if used.
- Team must have AWS credentials and EKS access; kubeconfig updated via `aws eks update-kubeconfig`.
