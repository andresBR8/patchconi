# 0018. Supply-chain policy: 3-day delay, SHA pins and blocked install scripts

- Status: Accepted
- Date: 2026-10-17
- Deciders: maintainer

## Context

Most compromised packages and releases are published by someone who stole a maintainer's credentials, and most are detected and removed within hours. Install scripts and moving references (tags) are the usual ways such code reaches a machine or a CI runner. PatchConi's own tooling (pnpm, pip, pre-commit, GitHub Actions, mise) pulls code from several registries, and its toolchain is covered in [ADR 0017](0017-mise-paranoid-toolchain.md).

## Decision

**1. Wait 3 days before using any new release.**

- pnpm: `minimumReleaseAge: 4320` in `pnpm-workspace.yaml` (strict: resolution fails instead of falling back to a newer version).
- pip: `PIP_UPLOADED_PRIOR_TO = "P3D"` in the `[env]` of `mise.toml`. It also covers pip's isolated builds, such as the setuptools that pre-commit downloads to build its placeholder package.
- Renovate: `minimumReleaseAge: "3 days"`.
- Manual pins (mise tools, actions, pre-commit dependencies): only versions published at least 3 days earlier.

**2. Pin by immutable references.**

- GitHub Actions by full commit SHA, with the version in a comment. zizmor flags unpinned actions, and its online audits detect impostor commits.
- Every dependency through a lockfile (`pnpm-lock.yaml`, `mise.lock`).

**3. Block dependency install scripts.** `strictDepBuilds: true` with an empty `allowBuilds`: any dependency with an install script fails the install until it is allowlisted with a comment explaining why. `trustPolicy: no-downgrade` and `blockExoticSubdeps: true` reject packages whose trust evidence got weaker and transitive dependencies from git or tarball URLs.

**4. pre-commit hooks from PyPI with pinned dependencies.** The pre-commit-hooks checks run as `repo: local` hooks with `additional_dependencies: ["pre-commit-hooks==6.0.0", "ruamel.yaml==0.19.1"]`, identical in every hook so that one environment is built, and `language: python` so Renovate can update them. Their definitions are copied from the upstream manifest at v6.0.0.

- pre-commit drops `GIT_CONFIG_PARAMETERS`, so it cannot clone the hook repository through the assistant's sandbox proxy.
- A prebuilt wheel avoids building pre-commit-hooks from source. (pip still downloads setuptools once, to build pre-commit's placeholder package; `PIP_UPLOADED_PRIOR_TO` delays it.)
- gitleaks, actionlint (with shellcheck) and zizmor run as `system` hooks with the binaries pinned by mise.

**5. Updates that need a human decision.** In Renovate:

- gitleaks waits for approval on the Dependency Dashboard: its version also appears in the ldflags, and the tag must be checked against proxy.golang.org.
- The mise version and SHA-256 used in CI wait for approval as well, to stay in step with the development machine.
- pnpm's two pins (mise and `packageManager`) are grouped in one pull request.
- Only even Node.js majors are allowed, and major updates carry a reminder not to merge before the release is LTS.
- Automerge stays off.

**6. Urgent security fixes.** Renovate opens vulnerability pull requests without waiting: in Renovate's source (`lib/config/options/index.ts`), `vulnerabilityAlerts` defaults to `minimumReleaseAge: null`, `schedule: []`, `dependencyDashboardApproval: false` and `prCreation: 'immediate'`. They need Dependabot alerts enabled on the repository. Renovate's delay is skipped, but **pnpm's and pip's are not**, so a fix younger than 3 days needs an explicit, temporary exception, in its own reviewed pull request, with a comment giving the reason and the date it will be removed:

- **pnpm:** add **that exact version only** to `minimumReleaseAgeExclude` in `pnpm-workspace.yaml` (`package@1.2.3`; pnpm 12 documents exact-version exclusions). With `minimumReleaseAge` set explicitly, pnpm is strict and fails resolution instead of picking another version, so the lockfile cannot be regenerated until the exception is in place. Pending: not reproduced here (pnpm cannot write its store lock inside the assistant's sandbox); confirm on the first real case ([issue #11](https://github.com/andresBR8/patchconi/issues/11)).
- **pip:** pip 26.2.1, the version pre-commit uses, has **no per-package exclusion**. Tested: with `PIP_UPLOADED_PRIOR_TO=P3D` a release uploaded 2 days earlier is not found ("No matching distribution"); with `P1D` it installs. The cutoff also accepts an absolute timestamp, tested to the minute: a timestamp just after the fix's upload lets it in. The exception is therefore a temporary change of `PIP_UPLOADED_PRIOR_TO` in `mise.toml` to the timestamp right after the fix's upload. It opens the window for every package pip resolves in that run, including the unpinned setuptools, so it is kept as short as possible. The alternative is to wait until the fix is 3 days old.
- Remove the exception on the date in the comment.
- An old pip ignores `PIP_UPLOADED_PRIOR_TO` without any warning (tested with pip 24.0). The cutoff only works with the pip that pre-commit's virtualenv provides.

## Alternatives considered

- **Install the latest release immediately** — exposes every machine and CI run to compromised releases during the window when they are most likely to be live.
- **Pin actions by tag** — tags can be moved; a SHA cannot.
- **Allow dependency install scripts by default** — the most common way malicious npm packages run code.
- **pre-commit-hooks from its git repository pinned by SHA** — the strongest pin, but it cannot be cloned through the sandbox proxy, and pip has to build the package from source.

## Consequences

- Positive: compromised releases have time to be detected before they reach the project; references cannot move under us.
- Negative and trade-offs: urgent fixes need the documented exception, and for pip it cannot be limited to one package; three registries (npm, PyPI, GitHub) each apply the delay their own way.
- Negative and trade-offs, residual risks:
  - PyPI lets a maintainer add new files to a published version, and pre-commit cannot pin dependencies by hash.
  - The setuptools version is not pinned, only delayed.
  - A `git commit` from a shell without mise activated does not get `PIP_UPLOADED_PRIOR_TO`.
  - The system `python3` is not pinned.
- Follow-ups:
  - Replace the Python hooks with binaries pinned by mise (for example editorconfig-checker and taplo), with checksums in `mise.lock`: [issue #9](https://github.com/andresBR8/patchconi/issues/9) (phase 1). It also removes the `SKIP=end-of-file-fixer` workaround in the assistant's sandbox.
  - Confirm the pnpm exception with an exact version on the first real urgent fix: [issue #11](https://github.com/andresBR8/patchconi/issues/11).
  - Revisit the even-majors rule for Node.js before April 2027, when Node 27 starts a new release schedule: [issue #12](https://github.com/andresBR8/patchconi/issues/12).
