# PatchConi

A self-hosted, read-only patch compliance dashboard for small Linux fleets.

> **Status: pre-alpha.** There is no product code yet and nothing to install. This repository currently holds the project's foundations: a pinned toolchain, repository hygiene checks, CI and dependency automation. The first release is planned as v0.1.0.

## What exists today

- **Pinned toolchain** with [mise](https://mise.jdx.dev/): `mise.toml` pins every tool to an exact version and `mise.lock` records download URLs and checksums for Linux and macOS (x64 and arm64). gitleaks, editorconfig-checker and tomljson are the exception: they are built from source and verified through sum.golang.org, so `mise.lock` records no checksum for them.
- **Hardened pnpm workspace** (`pnpm-workspace.yaml`): only versions published at least 3 days ago, dependency install scripts blocked unless allowlisted, trust-downgrade and exotic-source checks.
- **pre-commit hooks** (`.pre-commit-config.yaml`): file hygiene with tools pinned by mise (no hook installs anything when it runs), [gitleaks](https://github.com/gitleaks/gitleaks) on staged changes and on the whole history, [actionlint](https://github.com/rhysd/actionlint) with shellcheck, and [zizmor](https://github.com/zizmorcore/zizmor) for GitHub Actions security.
- **CI** (`.github/workflows/hygiene.yml`): runs the same hooks plus zizmor's online audits on every pull request and on `main`. Actions are pinned by commit SHA and the token is read-only.
- **Dependency updates** with [Renovate](https://docs.renovatebot.com/) (`renovate.json`): a 3-day delay before proposing a release, weekly batches, and manual approval for the updates that need a closer look.
- **Platform contract** ([`docs/platform-contract.md`](docs/platform-contract.md)): the rules every PatchConi artifact will follow to run on a container platform.

## Planned

None of this exists yet. It is the target for v0.1.0 and may change.

- **Agent** (Go): runs on each host from a systemd timer, without root, and reports pending updates, security advisories, the running kernel and the last reboot. It is read-only: it never installs packages or runs commands received from the server.
- **API** (NestJS, Drizzle, PostgreSQL): receives agent reports over HTTPS with a per-host token, stores history and evaluates a patch policy.
- **Web UI** (React, Vite): fleet overview, host details and history, host enrollment, users with administrator and read-only roles.
- **Alerts and metrics**: a generic webhook when a host breaks the policy, and Prometheus metrics.
- **Deployment artifacts**: container images, agent packages, a Docker Compose example and a Kustomize base.

Design principles: the agent only observes; least privilege; the host always starts the connection; machines that are switched off are fine; easy to self-host.

## Repository layout

| Path | Contents |
| --- | --- |
| `mise.toml`, `mise.lock` | Pinned developer toolchain |
| `package.json`, `pnpm-workspace.yaml`, `pnpm-lock.yaml` | pnpm workspace (no packages yet) |
| `.pre-commit-config.yaml`, `.editorconfig-checker.json` | pre-commit hooks and their configuration |
| `scripts/hooks/` | Small scripts that pre-commit hooks run |
| `.github/workflows/` | CI |
| `renovate.json` | Dependency update configuration |
| `protocol/` | Agent report contract: JSON Schema, OpenAPI draft, examples and the `apt`/`dnf` captures they come from |
| `docs/product/` | Product vision, patch policy, domain model, agent protocol and roadmap (drafts) |
| `docs/architecture.md` | System context and containers (C4) |
| `docs/threat-model.md` | Threat model: trust boundaries, threats, mitigations and accepted risks |
| `docs/platform-contract.md` | Deployment contract for container platforms |
| `docs/aprendizaje/` | The maintainer's learning notes and project plan, in Spanish |
| `CLAUDE.md`, `.claude/` | Instructions and guardrails for the AI coding assistant used during development |

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

Please report vulnerabilities privately. See [SECURITY.md](SECURITY.md).

## License

[Apache License 2.0](LICENSE).
