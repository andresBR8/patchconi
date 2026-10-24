# 0006. Per-host agent tokens with an identifiable prefix, stored as hashes

- Status: Accepted
- Date: 2026-10-16
- Deciders: maintainer

## Context

Each agent authenticates to the API to send its reports. Hosts are added and removed over time, and a host can be compromised or decommissioned. The database itself may leak (a backup, a misconfigured volume).

## Decision

One token per host, shown once when the host is enrolled. The token has an identifiable prefix (so it can be recognized in logs, secret scanners and support requests) and only its hash is stored. Tokens can be rotated and revoked.

- Revocable one by one: a lost or compromised host is cut off without touching the others.
- A database leak does not expose valid tokens, because only hashes are stored.

## Alternatives considered

- **mTLS client certificates** — strong, but they need a certificate authority, issuance and renewal for every host, which is a lot to ask of a small self-hosted install. Candidate for v2.

## Consequences

- Positive: per-host revocation and rotation; leaked hashes are useless to an attacker.
- Positive: the prefix lets secret scanners detect leaked tokens with a simple custom rule (for example, a gitleaks rule).
- Negative and trade-offs: a lost token cannot be recovered, only replaced; comparison has to be constant-time.
- Follow-ups: token issuance, rotation and revocation in phase 4. The [domain model](../product/domain-model.md#invariants-and-backend-rules) stores tokens with HMAC-SHA-256 and a server key; that key is a new server secret (losing it invalidates every token), and how it is supplied and rotated is decided in phase 4.
