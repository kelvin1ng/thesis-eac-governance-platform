# apps/firewall — Virtual Firewall CNF

**Reference:** CHAPTER3_REFERENCE.md §3.0, §3.2.2, Table 1 (Helm, Kustomize). Layer 3: gosec applies.

Minimal Go-based containerized virtual firewall: HTTP server on **port 8080**, **configurable rules** (env `FIREWALL_RULES`), **netfilter stub** in `pkg/rule` for packet-inspection simulation and gosec static analysis.

## Build

```bash
go build -o firewall ./cmd/firewall
```

## Run locally

```bash
PORT=8080 ./firewall
# Health: http://localhost:8080/health
# Rules:  http://localhost:8080/rules
# Check:  http://localhost:8080/check?port=8080
```

## Docker (Kaniko-ready)

Dockerfile is multi-stage, no daemon required (for Tekton/Kaniko):

```bash
docker build -t thesis-eac/firewall:latest .
```

## Deploy (Helm)

```bash
helm install firewall ./helm -n firewall --create-namespace
# Use image.digest in values for digest-only (Gatekeeper cosign constraint)
```

## Deploy (Kustomize)

```bash
kubectl apply -k kustomize/overlays/dev
```

## Traceability labels

Manifests include `owner`, `environment`, `compliance-scope` per §3.2.2. Capabilities limited to `NET_RAW`, `NET_ADMIN` for packet inspection.
