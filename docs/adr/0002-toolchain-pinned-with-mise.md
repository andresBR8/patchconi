# 0002. Toolchain pinned per repository with mise

- Status: Accepted
- Date: 2026-10-16
- Deciders: maintainer

## Context

Contributors and CI need the same versions of Node.js, pnpm, Go and the linters. Different versions on different machines produce different results and "works on my machine" bugs.

## Decision

[mise](https://mise.jdx.dev/) pins the toolchain in `mise.toml` at the repository root. Anyone, and CI, reproduces the exact environment with one command. How mise is used and secured (exact versions, `mise.lock`, paranoid mode) is described in [ADR 0017](0017-mise-paranoid-toolchain.md).

## Alternatives considered

- **Global installations on the development machine** — versions drift between machines and over time, CI has to replicate them separately, and nothing records which version a commit was tested with.

## Consequences

- Positive: one source of versions for laptops, CI and Renovate.
- Positive: changing a tool version is a reviewed commit.
- Negative and trade-offs: contributors must install and activate mise.
- Follow-ups: see ADR 0017.
