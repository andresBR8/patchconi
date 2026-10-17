# Platform deployment contract

- Version: 0.1
- Applies to: every PatchConi artifact meant to run on a container platform.
- Source of truth: the maintainer's platform repository keeps the canonical copy. This file is a versioned copy, so this repository never has to read the platform. If the two differ, update this copy in a dedicated commit.

PatchConi ships versioned artifacts. A platform decides where and how they run. Nothing in this repository is specific to one environment.

## 1. Container images

- One image per service, built with a multi-stage Dockerfile. The final stage contains only what runs.
- Base images are pinned by version; release builds also pin the digest.
- The process runs as a numeric non-root user and group (`10001:10001`). The final stage never runs as `root`.
- The container works with a read-only root filesystem. Writable paths (for example `/tmp`) are declared and mounted as `emptyDir`.
- The listening port comes from the `PORT` environment variable, with a documented default.
- Images are published to GHCR and deployed by digest. From v0.1.0 they are signed with cosign (keyless) and carry an SBOM and a provenance attestation.

## 2. Process behavior

- Configuration comes only from environment variables and is validated at startup. Invalid configuration fails fast with a clear message.
- Logs are JSON lines on stdout and stderr. No log files.
- `SIGTERM` triggers a graceful shutdown that finishes within 25 seconds.
- Nothing depends on always-on hosts or nightly jobs. Periodic work runs inside the API and is safe with several replicas.

## 3. Health and metrics endpoints

| Endpoint | Purpose | Rules |
| --- | --- | --- |
| `GET /healthz` | Liveness | The process is alive. It never checks dependencies such as the database. |
| `GET /readyz` | Readiness | Ready to serve: database reachable and schema at the expected migration. |
| `GET /metrics` | Prometheus metrics | From phase 7. Low-cardinality labels only. Not routed through the public Ingress. |

All three are unauthenticated, cheap and free of side effects.

## 4. Configuration and secrets

- The repository contains only `.env.example`, with every variable documented.
- Manifests reference Secrets by name and never create them. Names and keys are listed in `docs/deployment.md`.
- No secret is ever logged, baked into an image or passed as a build argument.

## 5. Database migrations

- Migrations run as a separate one-off command (`migrate`), never at application startup, so replicas never race.
- In Kubernetes they run as a Job before the new version rolls out; in Docker Compose, as a one-off service.
- Migrations are idempotent and backward compatible: expand first, contract in a later release.

## 6. Kubernetes manifests

Location: `deploy/kustomize/base`, plus `deploy/kustomize/overlays/example` as a reference overlay.

- Objects: a Deployment per service, Services, one Ingress (path-based on a single host: `/api` to the API, `/` to the web), the migration Job and ServiceAccounts.
- Mandatory on every container: resource requests and limits; startup, liveness and readiness probes; and this security context: `runAsNonRoot: true`, numeric `runAsUser` and `runAsGroup`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`, `seccompProfile.type: RuntimeDefault`.
- `automountServiceAccountToken: false` unless a component needs the Kubernetes API.
- The base contains no namespace, hostname, TLS settings, Secrets, image tags or replica counts for a specific environment. Platform overlays set them.
- CI validates every overlay with `kustomize build | kubeconform -strict` and `kube-linter`, and smoke-deploys it to an ephemeral kind cluster.

## 7. CI/CD

- GitHub Actions on GitHub-hosted runners. Actions pinned by full commit SHA; `GITHUB_TOKEN` read-only by default.
- Pipeline: lint and tests, build, Trivy scan (fails on critical findings), SBOM, push to GHCR (from `main` and release tags only).
- Releases are semantic-versioned tags. A platform consumes a released version through its own overlay and updates it with its own tooling, for example Renovate.

## 8. Handover to a platform

`docs/deployment.md` is the deployment sheet a platform reads to onboard PatchConi: images and digests, ports, health paths, environment variables, Secrets (names and keys, never values), default resources, the migration command, Ingress paths, metrics and version compatibility.
