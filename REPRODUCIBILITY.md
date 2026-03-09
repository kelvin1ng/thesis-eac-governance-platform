# Reproducibility Guide

This repository contains the implementation and evaluation artifacts for the MASc thesis:

**Unified Everything-as-Code Governance Platform**

The goal of this guide is to allow other researchers or practitioners to reproduce the experimental environment and evaluation results presented in **Chapter 4**.

---

## Repository Snapshot

To ensure reproducibility, the exact version of the platform used for evaluation is preserved using a Git tag.

Repository
https://github.com/kelvin1ng/thesis-eac-governance-platform

Evaluation Version
`thesis-v1.0`

This snapshot contains:

* Infrastructure-as-Code definitions (Terraform)
* Kubernetes manifests and Helm charts
* GitOps configuration (Argo CD)
* Policy-as-Code constraints (OPA Gatekeeper)
* Monitoring stack (Prometheus + Grafana)
* Threat testing framework
* Collected evaluation evidence

---

## System Architecture

The platform implements an integrated governance pipeline consisting of:

Git Repository
→ GitOps Controller (Argo CD)
→ Policy Engine (Gatekeeper / OPA)
→ Kubernetes Cluster
→ Monitoring Stack (Prometheus + Grafana)

This architecture enables continuous enforcement of governance controls and observable policy compliance.

---

## Environment Requirements

The following tools were used during the evaluation:

* Kubernetes cluster
* kubectl
* Helm
* Argo CD
* OPA Gatekeeper
* Prometheus
* Grafana
* Terraform
* Make

---

## Platform Deployment

Clone the repository:

```
git clone https://github.com/kelvin1ng/thesis-eac-governance-platform.git
cd thesis-eac-governance-platform
```

Checkout the evaluation snapshot:

```
git checkout thesis-v1.0
```

Deploy the platform components using the provided infrastructure and deployment scripts.

---

## Threat Testing

The repository includes a threat testing framework used to validate governance enforcement.

Run the threat test scenarios:

```
make threat-tests
```

These tests attempt to deploy workloads that violate governance policies (e.g., missing labels or unapproved container registries). The Gatekeeper admission controller should deny these requests.

---

## Monitoring and Metrics

Prometheus collects metrics from:

* Argo CD (GitOps synchronization state)
* Gatekeeper (policy admission decisions)
* Kubernetes components

These metrics are visualized through Grafana dashboards.

Example Prometheus queries used in the evaluation:

```
count(argocd_app_info{sync_status="OutOfSync"})
sum(gatekeeper_validation_request_count_total{admission_status="deny"})
rate(gatekeeper_validation_request_count_total[5m])
```

---

## Evidence Collection

Evidence artifacts were automatically collected after the evaluation:

```
make collect-evidence
```

Artifacts are stored under:

```
docs/evidence/
```

These files include:

* Argo CD application states
* Gatekeeper constraints
* Kubernetes resource snapshots
* Threat testing logs
* Monitoring configuration details

---

## Reproducing the Evaluation

To reproduce the Chapter 4 evaluation:

1. Deploy the platform environment
2. Run the threat testing scenarios
3. Observe policy enforcement events
4. Query Prometheus metrics
5. Validate results against the provided evidence artifacts

---

## Research Contribution

This repository demonstrates an integrated governance platform that combines:

* Infrastructure-as-Code
* GitOps deployment workflows
* Policy-as-Code enforcement
* Observability-driven compliance monitoring

The platform illustrates how governance controls can be enforced and measured within a cloud-native environment using Everything-as-Code principles.
