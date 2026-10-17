# 0011. Deployment: Docker Compose example and Kustomize base; Helm later

- Status: Accepted
- Date: 2026-10-16
- Deciders: maintainer

## Context

PatchConi targets small fleets. Some users run a single Docker host; others run Kubernetes. This repository ships artifacts and never deploys anywhere: platforms consume them through their own overlays (platform contract).

## Decision

Ship a Docker Compose example and a Kustomize base with an example overlay. A Helm chart comes after v0.1.0.

This covers both Compose and Kubernetes users without maintaining two complete packaging systems from the start.

## Alternatives considered

- **Only Helm from the start** — leaves Compose users out, and a chart is more to maintain than a Kustomize base while the manifests are still changing.

## Consequences

- Positive: Compose users get a quick start; Kubernetes users get a base they can patch without forking.
- Positive: Kustomize overlays match how platforms add environment-specific settings.
- Negative and trade-offs: users who expect a Helm chart have to wait.
- Follow-ups: Compose and the Kustomize base in phase 2, validated with kubeconform and kube-linter and deployed to kind in CI; Helm after v0.1.0.
