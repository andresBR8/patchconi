# 0015. Git flow: a branch per step, pull request with required CI, squash merge

- Status: Accepted
- Date: 2026-10-16
- Deciders: maintainer

## Context

The project advances in small steps, each reviewed by the maintainer (and by an independent review). `main` should always be releasable, and its history should read as a list of steps.

## Decision

- Every change goes on a branch (`phase-NN/<topic>`) and reaches `main` through a pull request.
- The `hygiene` CI check must pass before merging.
- Pull requests are squash-merged: one commit on `main` per step.
- A ruleset on `main` enforces this with no bypass list, for the maintainer and for bots alike: pull request required, `hygiene` required, squash only, no force-push and no deletion.

Every change goes through CI and review, `main` is always green, and squash leaves one commit per step. The ruleset enforces it without exceptions.

## Alternatives considered

- **Direct pushes to `main`** — faster, but changes skip CI and review, and a broken `main` is found after the fact.

## Consequences

- Positive: `main` is always green; history reads as one commit per step; bots such as Renovate are bound by the same rules.
- Negative and trade-offs: even a typo fix needs a branch and a pull request; the maintainer cannot bypass the rules in an emergency without changing the ruleset.
- Follow-ups: none.
