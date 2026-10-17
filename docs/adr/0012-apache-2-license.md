# 0012. Apache License 2.0

- Status: Accepted
- Date: 2026-10-16
- Deciders: maintainer

## Context

PatchConi is a public product meant to be installed and modified by anyone. The license decides how it can be used and what protection contributors and users get.

## Decision

The [Apache License 2.0](../../LICENSE): the canonical text published by the Apache Software Foundation. Contributions are licensed under the same terms (section 5), without a CLA.

It is the standard license in the cloud native ecosystem and includes an explicit patent grant.

## Alternatives considered

- **MIT** — simpler and very permissive, but without an explicit patent grant.
- **AGPL** — would force anyone offering a modified PatchConi as a service to publish their changes, but it discourages adoption by companies and is unusual in the ecosystem PatchConi lives in.

## Consequences

- Positive: familiar to users and companies; patent protection for users and contributors.
- Negative and trade-offs: others can build closed products on top of PatchConi.
- Follow-ups: none.
