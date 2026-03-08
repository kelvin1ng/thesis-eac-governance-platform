.PHONY: help prep infra kubeconfig addons policies argocd monitoring verify threat-tests health grafana prometheus cost-check destroy deploy verify-all cluster nodes pods events services tf-plan tf-apply tf-destroy preflight smoke collect-evidence ci-local

# Makefile — DevSecOps workflow for thesis-eac-governance-platform
# Wraps scripts/deploy/*.sh and scripts/ops/*.sh. Run from repo root (WSL).
# Scripts source environments/dev/env.sh; Make defaults mirror that contract.

SHELL := /bin/bash
.DEFAULT_GOAL := help

REPO_ROOT := $(shell git rev-parse --show-toplevel 2>/dev/null || echo ".")
ENV_TFVARS := $(REPO_ROOT)/environments/dev/terraform.tfvars

# Environment (mirrors environments/dev/env.sh; override by exporting before make)
AWS_PROFILE ?= thesis
AWS_REGION ?= us-east-1
CLUSTER_NAME ?= thesis-eac-eks
MONITORING_RELEASE ?= kps

export AWS_PROFILE
export AWS_REGION
export CLUSTER_NAME
export MONITORING_RELEASE

# Phase scripts (run from repo root)
PREP_SCRIPT       := scripts/deploy/00-phase0-local-prep.sh
INFRA_SCRIPT      := scripts/deploy/01-phase1-terraform.sh
KUBECONFIG_SCRIPT := scripts/deploy/02-phase2-kubeconfig.sh
ADDONS_SCRIPT     := scripts/deploy/03-phase3-core-addons.sh
POLICIES_SCRIPT   := scripts/deploy/04-phase4-gatekeeper-policies.sh
ARGOCD_SCRIPT     := scripts/deploy/05-phase5-argocd-apps.sh
MONITORING_SCRIPT := scripts/deploy/06-phase6-monitoring.sh
VERIFY_SCRIPT     := scripts/deploy/07-phase7-verification.sh
THREAT_SCRIPT     := scripts/deploy/08-phase8-threat-tests.sh

OPS_PREFLIGHT := scripts/ops/preflight-check.sh
OPS_EVIDENCE  := scripts/ops/collect-evidence.sh
OPS_HEALTH    := scripts/ops/eks-health-check.sh
OPS_GRAFANA   := scripts/ops/grafana-access.sh
OPS_PROM      := scripts/ops/prometheus-access.sh
OPS_COST      := scripts/ops/aws-cost-check.sh
OPS_DESTROY   := scripts/ops/destroy-cluster.sh

SMOKE_CLUSTER    := tests/smoke/check-cluster.sh
SMOKE_ARGOCD     := tests/smoke/check-argocd.sh
SMOKE_GATEKEEPER := tests/smoke/check-gatekeeper.sh
SMOKE_MONITORING := tests/smoke/check-monitoring.sh

# ------------------------------------------------------------------------------
# Deployment phases (wrap existing scripts)
# ------------------------------------------------------------------------------

prep:
	@cd $(REPO_ROOT) && bash $(PREP_SCRIPT)

infra:
	@cd $(REPO_ROOT) && bash $(INFRA_SCRIPT)

kubeconfig:
	@cd $(REPO_ROOT) && bash $(KUBECONFIG_SCRIPT)

addons:
	@cd $(REPO_ROOT) && bash $(ADDONS_SCRIPT)

policies:
	@cd $(REPO_ROOT) && bash $(POLICIES_SCRIPT)

argocd:
	@cd $(REPO_ROOT) && bash $(ARGOCD_SCRIPT)

monitoring:
	@cd $(REPO_ROOT) && bash $(MONITORING_SCRIPT)

verify:
	@cd $(REPO_ROOT) && bash $(VERIFY_SCRIPT)

threat-tests:
	@cd $(REPO_ROOT) && bash $(THREAT_SCRIPT)

# ------------------------------------------------------------------------------
# Preflight, smoke, evidence, CI-local
# ------------------------------------------------------------------------------

preflight:
	@cd $(REPO_ROOT) && bash $(OPS_PREFLIGHT)

smoke:
	@cd $(REPO_ROOT) && bash $(SMOKE_CLUSTER) && bash $(SMOKE_ARGOCD) && bash $(SMOKE_GATEKEEPER) && bash $(SMOKE_MONITORING)

collect-evidence:
	@cd $(REPO_ROOT) && bash $(OPS_EVIDENCE)

ci-local:
	@cd $(REPO_ROOT) && (command -v shellcheck >/dev/null && find scripts tests -name '*.sh' -exec shellcheck {} + || true); \
	cd infra && terraform fmt -check && terraform init -backend=false && terraform validate; \
	(command -v yamllint >/dev/null && yamllint -d relaxed . 2>/dev/null || true)

# ------------------------------------------------------------------------------
# Operations
# ------------------------------------------------------------------------------

health:
	@cd $(REPO_ROOT) && bash $(OPS_HEALTH)

grafana:
	@cd $(REPO_ROOT) && bash $(OPS_GRAFANA)

prometheus:
	@cd $(REPO_ROOT) && bash $(OPS_PROM)

cost-check:
	@cd $(REPO_ROOT) && bash $(OPS_COST)

destroy:
	@cd $(REPO_ROOT) && bash $(OPS_DESTROY)

# ------------------------------------------------------------------------------
# Pipelines
# ------------------------------------------------------------------------------

deploy: prep infra kubeconfig addons policies argocd monitoring
	@echo "Deploy pipeline complete."

verify-all: verify threat-tests health
	@echo "Verify-all pipeline complete."

# ------------------------------------------------------------------------------
# Debugging
# ------------------------------------------------------------------------------

cluster:
	kubectl cluster-info

nodes:
	kubectl get nodes -o wide

pods:
	kubectl get pods -A

events:
	kubectl get events -A --sort-by=.metadata.creationTimestamp | tail -n 25

services:
	kubectl get svc -A

# ------------------------------------------------------------------------------
# Terraform helpers (use environments/dev/terraform.tfvars)
# ------------------------------------------------------------------------------

tf-plan:
	cd $(REPO_ROOT)/infra && terraform plan -var-file=$(ENV_TFVARS)

tf-apply:
	cd $(REPO_ROOT)/infra && terraform apply -auto-approve -var-file=$(ENV_TFVARS)

tf-destroy:
	cd $(REPO_ROOT)/infra && terraform destroy -auto-approve -var-file=$(ENV_TFVARS)

# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------

help:
	@echo "Available targets:"
	@echo ""
	@echo "  make prep            Prepare local environment"
	@echo "  make infra           Deploy AWS infrastructure"
	@echo "  make kubeconfig      Configure kubectl"
	@echo "  make addons          Install Gatekeeper and Argo CD"
	@echo "  make policies        Apply Gatekeeper policies"
	@echo "  make argocd          Deploy Argo CD applications"
	@echo "  make monitoring      Install monitoring stack"
	@echo "  make verify          Run verification steps"
	@echo "  make threat-tests    Run threat test suite"
	@echo ""
	@echo "Preflight / smoke / evidence:"
	@echo "  make preflight       Run preflight-check.sh"
	@echo "  make smoke           Run smoke tests (cluster, Argo CD, Gatekeeper, monitoring)"
	@echo "  make collect-evidence  Snapshot cluster state to docs/evidence/"
	@echo "  make ci-local        Run CI-style checks locally (shellcheck, tf fmt/validate, yamllint)"
	@echo ""
	@echo "Operations:"
	@echo "  make health          Run EKS health check"
	@echo "  make grafana         Open Grafana UI"
	@echo "  make prometheus      Open Prometheus UI"
	@echo "  make cost-check      Show AWS cost risks"
	@echo "  make destroy         Destroy infrastructure"
	@echo ""
	@echo "Pipelines:"
	@echo "  make deploy          Full platform deployment"
	@echo "  make verify-all      Full verification pipeline"
	@echo ""
	@echo "Debugging:"
	@echo "  make cluster         kubectl cluster-info"
	@echo "  make nodes           kubectl get nodes -o wide"
	@echo "  make pods            kubectl get pods -A"
	@echo "  make events          Recent cluster events"
	@echo "  make services        kubectl get svc -A"
	@echo ""
	@echo "Terraform:"
	@echo "  make tf-plan         terraform plan"
	@echo "  make tf-apply        terraform apply -auto-approve"
	@echo "  make tf-destroy      terraform destroy -auto-approve"
