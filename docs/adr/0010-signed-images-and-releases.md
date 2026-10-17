# 0010. Distribution: signed images on GHCR with SBOM and provenance; GoReleaser for the agent

- Status: Accepted
- Date: 2026-10-16
- Deciders: maintainer

## Context

PatchConi runs with access to an inventory of hosts and their pending updates, and its agent runs on every one of those hosts. People installing it need to know that what they run is what this repository built.

## Decision

- Container images are published to GitHub Container Registry, signed keyless with cosign, with an SBOM and a provenance attestation, and deployed by digest.
- Agent releases are built with GoReleaser: archives, `.deb` and `.rpm` packages and checksums. The install script verifies the checksums.

Anyone can verify what they run.

## Alternatives considered

- **Unsigned images** — simpler, but users cannot tell whether an image was built by this repository's CI or tampered with along the way.

## Consequences

- Positive: verifiable artifacts (`cosign verify`), an inventory of components (SBOM) and a record of how each artifact was built.
- Negative and trade-offs: a more complex release pipeline; signing depends on GitHub's OIDC identity.
- Follow-ups: push by digest from phase 2; signing, SBOM and provenance in the v0.1.0 release (phase 8), with `cosign verify` documented.
