# 0017. mise toolchain: exact pins, lockfile and paranoid mode

- Status: Accepted
- Date: 2026-10-17
- Deciders: maintainer

## Context

[ADR 0002](0002-toolchain-pinned-with-mise.md) chose mise to pin the toolchain. A pinned version alone does not guarantee that every machine downloads the same artifact, and `mise.toml` itself can run code: its `[env]` section changes the environment, and backend options such as `install_env` change how tools are built. The AI coding assistant writes this file, but the installations run outside its sandbox ([ADR 0016](0016-claude-code-guardrails.md)).

## Decision

- **Exact versions** in `mise.toml`, each at least 3 days old when pinned ([ADR 0018](0018-supply-chain-policy.md)).
- **`mise.lock`** records, for each binary tool, the resolved version, download URL and checksum for `linux-x64`, `linux-arm64`, `macos-x64` and `macos-arm64` (`lockfile_platforms`); gitleaks is the exception (see below). Installs use `mise install --locked`.
- **Backends:** Node.js and Go use mise's built-in core backends (`node`, `go`). Every other tool names its backend explicitly (`aqua:` for binaries from GitHub releases, with checksums and provenance when the release publishes it; `go:` for gitleaks), so its source does not depend on mise's registry defaults.
- **gitleaks is built from source** with the `go:` backend. Its v8.30.1 tag was moved after release to a commit that only changes `.goreleaser.yml`, and the release binaries carry no signature or provenance. Comparing them with the release's own `checksums.txt` proves nothing, because both come from the same source. The `go:` backend builds the code recorded by proxy.golang.org and verified by sum.golang.org, with `GOPROXY`, `GOSUMDB` and `GOTOOLCHAIN=local` pinned in `install_env`, and the official build tag and ldflags.
- **Paranoid mode on the development machine:** configured in mise's global configuration, outside the repository, because a repository cannot change it. mise trusts a project config by its **content hash**, so any change to `mise.toml` must be reviewed and trusted again (`mise trust`) before it loads. Paranoid mode also re-verifies provenance on every install.
- **Installations run outside the assistant's sandbox, by the maintainer**, always in this order: review `mise.toml` → `mise trust` → `mise lock` → review `mise.lock` → `mise install --locked`.

`mise.lock` is not a config file, so paranoid mode does not ask to trust it again when it changes. It is reviewed under rule 11 instead.

## Alternatives considered

- **Default trust (by path)** — after a `git pull`, a changed `mise.toml` applies without asking.
- **Fuzzy versions (`node = "24"`) resolved by the lockfile only** — the version that gets installed changes without a visible change to `mise.toml`.
- **gitleaks release binaries**, checked against the release's `checksums.txt` — rejected because of the moved tag (see above).
- **`minimum_release_age` in mise** — mise does not apply it to exact versions or versions recorded in `mise.lock`, so it adds nothing here.
- **Letting the assistant run `mise install`** — rejected in ADR 0016.

## Consequences

- Positive: every machine and CI installs the same artifacts; a change to what runs is always a reviewed diff.
- Positive: gitleaks is verified against a transparency log that cannot be rewritten.
- Negative and trade-offs: every change to `mise.toml` costs a `mise trust`; the first gitleaks install compiles (about a minute).
- Negative and trade-offs: gitleaks has no checksum in `mise.lock`; its integrity depends on proxy.golang.org and sum.golang.org.
- Follow-ups: when Renovate proposes a new gitleaks, compare the GitHub tag with proxy.golang.org before merging. Update the mise version used in CI together with the development machine's mise.
