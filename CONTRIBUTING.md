# Contributing to PatchConi

Thanks for your interest. PatchConi is pre-alpha: there is no product code yet, so the most useful contributions right now are feedback on the plan, the tooling and the security model. Please open an issue before starting larger work.

## Supported platforms

**Linux and macOS, on x64 and arm64**, are expected to work: they are the four platforms recorded in `mise.lock`. Only Linux x64 is tested, in CI. Windows is not supported.

## Requirements

- [mise](https://mise.jdx.dev/getting-started.html), **activated in your shell** (see [Activate mise](https://mise.jdx.dev/getting-started.html#activate-mise) in the official guide) or with its shims on your `PATH`. The pre-commit hooks look for the tools pinned in `mise.toml` on the `PATH` (editorconfig-checker, yq, tomljson, shellcheck, gitleaks, actionlint, zizmor). The `[env]` section of `mise.toml` also sets `PIP_UPLOADED_PRIOR_TO`: no hook installs Python packages today, so pip does not use it to set up the hooks, but it stays as a safety net for any hook that would.
- `git`, `bash` and `python3` (pre-commit runs on the system Python, and the hook scripts in `scripts/hooks/` use `bash` and `python3`).

Every other tool (Node.js, pnpm, Go, pre-commit, editorconfig-checker, yq, tomljson, gitleaks, actionlint, shellcheck, zizmor) is pinned in `mise.toml` and installed by mise.

## Setup

```sh
git clone https://github.com/andresBR8/patchconi.git
cd patchconi
```

**Read `mise.toml` before you trust it.** Trusting it lets mise apply its `[env]` section to your shell and its `install_env` options when it builds tools, and it decides which binaries get downloaded and run.

```sh
mise trust mise.toml
mise install --locked
pnpm install --frozen-lockfile
pre-commit install
pre-commit run --all-files
```

- `mise install --locked` installs exactly the versions, URLs and checksums recorded in `mise.lock`. gitleaks has no URL or checksum there: it is built from source and verified through sum.golang.org.
- `pnpm install --frozen-lockfile` fails if `pnpm-lock.yaml` does not match `package.json`.
- `pre-commit install` adds the git hook, so the checks run on every commit. Run it again after pre-commit itself is upgraded.

By default mise trusts a config file by its **path**: after a `git pull`, a changed `mise.toml` (another tool, another `[env]`) applies without asking. Read `mise.toml` again after every pull that changes it. In [paranoid mode](https://mise.jdx.dev/paranoid.html), mise trusts the file's **content** instead, so any change has to be trusted again. `mise trust --show` lists which config files are trusted.

## Rules

- **pnpm only.** Do not use npm, npx or yarn.
- **Pin everything.** Dependencies through the lockfile, tools through `mise.toml`, GitHub Actions by full commit SHA with the version in a comment.
- **New versions wait 3 days.** pnpm (`minimumReleaseAge`), pip (`PIP_UPLOADED_PRIOR_TO`) and Renovate only take releases published at least 3 days ago. Do not pin anything newer.
- **No install scripts by default.** A dependency that needs one goes into `allowBuilds` in `pnpm-workspace.yaml`, with a comment explaining why.
- **No secrets** in the repository. gitleaks runs on every commit and in CI.
- **Files that run code get a separate review.** The criterion: any file, tracked or not, that a tool executes or that changes what a tool executes. They run on contributors' machines, in CI or on users' hosts, so every change to one of them must be called out in the pull request description. Some examples, not a complete list: `.github/**`, `mise.toml` and `mise.lock`, `package.json` (scripts, `packageManager`), `pnpm-workspace.yaml`, `.npmrc`, `.pnpmfile.cjs`, lockfiles, `go.mod` and `go.sum`, `.pre-commit-config.yaml` and the scripts in `scripts/`, tool configs written in code (`*.config.ts`), Dockerfiles, `deploy/**`, and `CLAUDE.md` and `.claude/` (for example, `.claude/settings.json` can define hooks that run commands). Rule 11 in `CLAUDE.md` is the same rule and keeps the fuller list of examples.

## Commits and pull requests

- Work on a branch and open a pull request against `main`. Direct pushes to `main` are blocked.
- Use [Conventional Commits](https://www.conventionalcommits.org/) in English, in the imperative mood: `feat:`, `fix:`, `docs:`, `chore:`, `test:`, `ci:`, `refactor:`, `build:`.
- The `hygiene` check must pass. Pull requests are squash-merged.
- Code, comments, commit messages and product docs are written in English.

## License

By contributing, you agree that your contributions are licensed under the Apache License 2.0, as described in section 5 of the [LICENSE](LICENSE). There is no CLA.
