# CHAPTER3_REFERENCE.md §3.2.3 Layer 3: Kaniko-ready (no daemon); Table 1.
# Multi-stage build for minimal image; runs in Tekton/Kaniko without Docker socket.
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /firewall ./cmd/firewall

FROM alpine:3.19
RUN apk --no-cache add ca-certificates
COPY --from=builder /firewall /firewall
# Traceability: port 8080 per §3.0
EXPOSE 8080
USER 1000:1000
ENTRYPOINT ["/firewall"]
