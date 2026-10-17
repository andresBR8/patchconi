---
paths:
  - "**/Dockerfile*"
  - "**/*.Dockerfile"
  - "deploy/**"
  - "compose*.y*ml"
  - "**/compose*.y*ml"
---

# Container and deployment rules

Follow `docs/platform-contract.md`. In short:

- Multi-stage builds, base images pinned by version, minimal final stage.
- Run as a numeric non-root UID/GID (`10001:10001`) and work with a read-only root filesystem.
- Listening port from the `PORT` environment variable. `/healthz` is liveness and never checks dependencies; `/readyz` is readiness.
- Kubernetes manifests always have requests/limits, probes and the restricted `securityContext`. The base has no namespace, hostnames, Secrets or environment-specific values.
- Compose files never mount host paths outside the repository and never mount the Docker socket.
- Every Dockerfile passes `hadolint`; every rendered manifest passes `kubeconform` and `kube-linter`.
