# 0001. Monorepo with pnpm workspaces, agent as a separate Go module

- Status: Accepted
- Date: 2026-10-16
- Deciders: maintainer

## Context

PatchConi has three components that must agree on one contract: a NestJS API, a React web UI and a Go agent. They are released together as one product version. The project is maintained by one person, so the repository layout has to keep cross-component changes cheap and keep container images small.

## Decision

One repository. The TypeScript packages (`apps/api`, `apps/web` and any shared `packages/*`) live in a pnpm workspace. The agent lives in `agent/` as its own Go module, outside the pnpm workspace.

- One API contract and one product version: a change to the protocol, the API and its clients lands in a single pull request and a single CI run.
- pnpm is strict about dependencies (a package can only import what it declares), and `pnpm deploy` produces a self-contained folder with only the dependencies one app needs, which keeps each image small.

## Alternatives considered

- **Separate repositories** per component — the contract would be versioned and released in several places, and every protocol change would need coordinated pull requests.
- **Turborepo** on top of the workspace — only worth it if CI becomes slow; not needed for three packages.

## Consequences

- Positive: atomic changes across API, web and agent; one CI pipeline; one release.
- Positive: strict dependency boundaries and small per-app images.
- Negative and trade-offs: two toolchains (Node and Go) in one repository; CI has to decide which jobs to run for which paths.
- Follow-ups: revisit Turborepo if CI time grows; `pnpm deploy` is used when the Dockerfiles are written (phase 2).
