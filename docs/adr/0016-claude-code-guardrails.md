# 0016. Guardrails for the AI coding assistant (Claude Code)

- Status: Accepted
- Date: 2026-10-17
- Deciders: maintainer

## Context

Development uses Claude Code, an AI coding assistant, on the maintainer's development VM. It reads and writes files and runs commands. Without limits it could read credentials, reach other repositories, control Docker (which is root on the VM), or write files that the maintainer, CI or users' hosts later execute with full rights.

## Decision

Three layers, configured in the versioned `.claude/settings.json` and in `CLAUDE.md`.

**1. Operating-system sandbox for every Bash command** (bubblewrap and seccomp). This is the real boundary; no command runs outside it.

- Writes only inside the repository and its temporary directory.
- Network only to allowed domains, through a filtering proxy.
- Unix sockets cannot be created, so the Docker socket is unreachable.
- Reads of credential directories (`~/.ssh`, `~/.kube`, `~/.docker`, cloud CLIs), of another repository on the machine and of `.env` files are denied.

**2. Permission rules** (`allow`, `ask`, `deny` in `settings.json`). They stop the assistant from choosing an action, but they are not a boundary by themselves.

- Denied commands: `docker`, `kind`, `kubectl`, `helm`, `terraform`, `ansible`, `packer`, `npm`, `npx`, `yarn`, `git push`, bulk `git add` and printing the environment.
- Edit and Write do not go through the sandbox, so `Edit` rules deny them on shell dotfiles, user configuration and caches, user-level Claude Code configuration, parent-directory mise and direnv files, and the repository's `.git/hooks` and `.git/config`. `Read` rules repeat the credential paths above.
- Installations are run by the maintainer, after review, from their own terminal. `mise install`, `pnpm install` and `pnpm install --frozen-lockfile` are not in `allow` (removed when phase 0 closed), so the assistant would need explicit approval for each run, and inside the sandbox they fail anyway because it cannot write to the tool caches.

**3. Human review of files that run outside the sandbox** (rule 11 in `CLAUDE.md`). Any file, tracked or not, that a tool executes or that changes what a tool executes is listed under «Revisar antes de ejecutar» in every review. The `reviewer` subagent's first, mandatory check produces that list.

Two operational rules follow from the sandbox:

- Files are staged by explicit path, never with `git add -A`: the sandbox mounts `/dev/null` placeholders over sensitive paths, and a bulk add would commit them.
- Branches are created with `git switch --no-track`: the sandbox does not allow writing `.git/config`, so recording an upstream fails, the switch exits with an error and leaves the assistant on `main`.

**Why the rules for `~/homelab` stay in the versioned `settings.json`.** `~/homelab` is the folder of another repository on the same machine, handled by a separate Claude Code session. It is a folder name, not an IP address or a hostname.

- Not in `.claude/settings.local.json`: that file is not versioned and nobody reviews it, so in a fresh clone the protection would disappear without warning.
- Not in the user-level `~/.claude/settings.json`: `deny` rules add up across scopes, so a user-level rule would also block the session that legitimately works in that repository.

## Alternatives considered

- **Permission rules only, without the sandbox** — `deny` rules restrain the assistant but are not a boundary: `Bash(curl *)` does not stop `/usr/bin/curl …` or `sh -c 'curl …'`. The real boundary is the operating-system sandbox.
- **Letting Docker out of the sandbox with a narrow pattern** (`docker compose *`) — rejected because the assistant writes `compose.yaml`, and a compose file can mount `~/.ssh` or the whole disk into a container.
- **Denying every read outside the repository** instead of a list of paths — stronger, but it may break Node.js and pnpm, which read files outside the repository. Not tried yet: tracked in [issue #10](https://github.com/andresBR8/patchconi/issues/10).
- **Letting the assistant run installations itself**, with write access to the tool caches — convenient, but it could poison binaries that later run outside the sandbox.
- **A blanket `Edit(~/.*/**)` deny** — simpler than a list, but `deny` rules have no exceptions, so it would also block files the assistant legitimately writes under its own configuration directory (plans and memory).
- **`~/homelab` rules in `settings.local.json` or in the user-level settings** — rejected for the reasons above.

## Consequences

- Positive: the assistant cannot read credentials, reach Docker or other repositories, or edit the user's configuration; deferred execution is caught by review.
- Positive: the protections are versioned, so every clone gets them.
- Negative and trade-offs: a deny list is never complete, and review is the last line of defence.
- Negative and trade-offs: the sandbox workarounds are **not** versioned. pre-commit's cache directory (`PRE_COMMIT_HOME`) and Go's build cache (`GOCACHE`) live in `.claude/settings.local.json` because their paths depend on the user's UID. A fresh clone has to recreate them; the pre-commit learning note describes them.
- Negative and trade-offs: `settings.json` names a local folder (`~/homelab`), which is environment-specific in a strict sense.
- Evidence (2026-10-25): a script that called `docker` passed the permission rules, which match the text of the command typed, not what it runs inside; the sandbox stopped it by blocking the Docker socket. That is why the boundary is the sandbox, not the permission rules.
- Follow-ups:
  - Resolved when phase 0 closed: `mise install`, `pnpm install` and `pnpm install --frozen-lockfile` were removed from `allow`.
  - Try denying every read outside the repository: [issue #10](https://github.com/andresBR8/patchconi/issues/10). Deferred to phase 2, before the application code (API, web and agent) enters the repository: phase 1 added documents and a few hook and capture scripts, but no Node.js or Go dependencies, which are what the stricter rule may break.
  - Review the Docker part in phase 2, when Docker enters development; a new ADR if it changes.
