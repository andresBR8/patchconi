# PatchConi — instructions for Claude Code

At the start of every session: read this file, `docs/aprendizaje/PROGRESO.md` (where we are) and the current phase in `docs/aprendizaje/PLAN.md`. Summarize the state in 3 lines and propose the next step before touching anything.

## What this repo is

PatchConi is a self-hosted, read-only patch compliance dashboard for small Linux fleets. An agent on each host reports pending updates; the server shows which hosts lag behind, since when, and alerts when a host breaks the patch policy.

- It is a generic, public product: anyone must be able to install it from the docs. It never contains anything specific to the maintainer's infrastructure (IPs, domains, hostnames, inventories, tokens).
- It ships versioned artifacts: container images, agent packages, a Kustomize base. Platforms consume them; this repo never deploys anywhere. Contract: `docs/platform-contract.md`.
- Plan, phases, accepted decisions and the Definition of Done: `docs/aprendizaje/PLAN.md`. Each accepted decision becomes an ADR in `docs/adr/`.

## Architecture (target)

- `apps/api`: NestJS + Drizzle + PostgreSQL. The only component that talks to the database.
- `apps/web`: React + Vite static SPA served by unprivileged nginx. Calls `/api` on the same origin.
- `agent/`: Go, read-only, started by a systemd timer. Reports to `/api/v1/agent/reports` with a per-host token.
- `deploy/`: Docker Compose example, Kustomize base and a generic Ansible role for the agent.
- Monorepo with pnpm workspaces; toolchain pinned with `mise`.

## How we work

- One step at a time. Before changing anything, explain in 2–6 lines what you will do and why, then wait for an OK.
- Explain the reasoning behind every technical decision, not just the command. The maintainer is learning and must be able to explain every piece.
- Work on a branch `phase-NN/<topic>` with small commits. The maintainer reviews, pushes and opens the PR; CI must be green before merging.
- Create branches with `git switch --no-track -c <branch> origin/main`: the sandbox does not allow writing `.git/config`, so without `--no-track` git fails to record the upstream, the switch exits with an error and you stay on `main`. Run `git branch --show-current` before every commit.
- Run the `verify` skill before every commit. Run the `reviewer` subagent on the diff before asking for review.
- A phase only closes through `/close-phase` (Definition of Done in `PLAN.md`).
- If two options are reasonable, ask. If one is clearly better, say which and why.
- If something fails, explain the cause before proposing a fix. No blind retries. Never disable a check, test or linter to get green.

## Rules

1. Never read, print or copy secrets: `.env` files, tokens, private keys. Never print environment variables. The deny rules cover `.env` and `.env.*`, `.env.example` included: permission rules have no `!` exceptions. Handling the template is decided in phase 2.
2. Stay inside this repository. Never touch other repositories, infrastructure or clusters: `kubectl`, `helm`, `terraform`, `ansible` and `packer` are denied here.
3. No secrets in versioned files; only `.env.example`. Before each commit: `pre-commit run --all-files` and review `git diff --staged`. Stage files by explicit path: never `git add -A`, `git add .` or `git commit -a`. On Linux the sandbox creates empty placeholder files (`.bashrc`, `.gitconfig`, `.claude/hooks`, ...) while a command runs, and a bulk add would commit them.
4. Never push. The maintainer runs `git push` from their own terminal after review.
5. Claude Code does not run Docker or kind: `docker` is denied and the sandbox blocks the Docker socket, because Docker access is root access on the dev machine. When a step needs them, propose the exact command and show any compose file change; the maintainer runs it from their own terminal.
6. Pin everything: dependencies through the lockfile, tools through `mise`, base images by version (and digest in releases), GitHub Actions by full commit SHA with the version in a comment.
7. pnpm only, never npm, npx or yarn. Dependency lifecycle scripts stay blocked unless allowlisted with a written reason. Before adding a dependency, say why and what it costs (size, maintenance, alternatives).
8. Check current versions (Node LTS, Go, PostgreSQL, libraries, actions) before pinning them. Never pin from memory.
9. The agent is read-only: it never installs packages or runs commands received from the server. Changing that needs an ADR and explicit approval.
10. The repository is public: write code, commits and docs as if a stranger reads them tomorrow.
11. Files that run outside the sandbox are reviewed first. The sandbox only confines Claude Code's own commands; the maintainer, the CI and the users' hosts later run other files with full rights. The criterion: any file, tracked or not, that runs code or configures how code runs outside the sandbox. Every change to such a file is listed at the top of every review and every diff summary, under «Revisar antes de ejecutar»: only the changed files, one line each (what it runs and when), or «Nada». The maintainer reviews them before running anything. The list includes at least:
    - Package managers: `package.json` (scripts, `packageManager`), `.pnpmfile.cjs`, `pnpm-workspace.yaml`, `pnpm-lock.yaml`, `.npmrc`, `go.mod`, `go.sum`
    - Toolchain: `mise.toml`, `mise.*.toml`, `.mise.toml`, `.config/mise*`, `mise.lock`, `.tool-versions`
    - Hooks and task runners: `.pre-commit-config.yaml`, `.husky/`, `lefthook.yml`, `Makefile`, `justfile`, `Taskfile.yml`, `scripts/`, `.envrc`, `.git/hooks/`, `.git/config`
    - Tool configs written in code: `*.config.{js,cjs,mjs,ts}` (ESLint, Vite, Vitest, Drizzle, ...)
    - CI and editors: `.github/**`, `.vscode/**`, `.devcontainer/`, `.idea/`
    - Containers and deployment: `Dockerfile*`, `compose*.y*ml`, `deploy/**`, agent packaging (systemd units, package scripts)
    - Claude Code: every `CLAUDE.md`, everything under `.claude/`, `.mcp.json`

## Conventions

- Language: code, identifiers, API, commits, README and product docs in English. `docs/aprendizaje/` is the maintainer's learning space, in Spanish.
- Commits: Conventional Commits in English (`feat:`, `fix:`, `docs:`, `chore:`, `test:`, `ci:`, `refactor:`, `build:`), imperative mood, one per logical step.
- ADRs: `docs/adr/NNNN-title.md`, one per decision (use `/new-adr`).
- Learning notes (Spanish): one concept per file in `docs/aprendizaje/conceptos/`; runbooks in `docs/aprendizaje/runbooks/NN-name.md`.
- `docs/aprendizaje/PROGRESO.md`: one line per finished step, `YYYY-MM-DD · phase · what was done · next step`. Update it before the session ends.
- Each package gets its own `CLAUDE.md` (`apps/api`, `apps/web`, `agent`) when it is created, with its commands and conventions.

## Commands

Filled in as they come to exist. Phase 0 target:

- `mise install` — install the pinned toolchain
- `pnpm install` — install dependencies (`--frozen-lockfile` in CI)
- `pnpm lint` · `pnpm typecheck` · `pnpm test`
- `pre-commit run --all-files`

## Environment

- Claude Code runs on a Linux dev VM with the Bash sandbox enabled (see `.claude/settings.json`). A command that fails inside the sandbox is reported and explained, never retried outside it.
- The maintainer's machines are not always on: nothing in the product may depend on nightly jobs or always-on hosts.
