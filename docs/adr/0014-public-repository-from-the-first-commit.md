# 0014. Public repository from the first commit

- Status: Accepted
- Date: 2026-10-16
- Deciders: maintainer

## Context

The repository could start private and be opened at v0.1.0, or be public from the beginning. Anything ever committed stays in the history.

## Decision

The repository is public from the first commit.

- It forces writing for the public from day one (no secrets, no environment-specific values, code and commits a stranger can read), instead of reviewing the whole history before opening it.
- On public repositories GitHub provides rulesets, secret scanning and private vulnerability reporting for free.

## Alternatives considered

- **Private until v0.1.0, then publish the whole history at once** — the history would need a full audit before opening, and the protections above would not be available while private.

## Consequences

- Positive: good habits from the start; free branch protection, secret scanning and private vulnerability reporting.
- Negative and trade-offs: every mistake is public immediately; work in progress is visible.
- Follow-ups: gitleaks on staged changes and on the whole history, locally and in CI ([ADR 0018](0018-supply-chain-policy.md) and the pre-commit configuration).
