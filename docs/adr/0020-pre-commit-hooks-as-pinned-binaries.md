# 0020. pre-commit hooks as binaries pinned by mise

- Status: Accepted
- Date: 2026-10-24
- Deciders: maintainer
- Supersedes: [ADR 0018](0018-supply-chain-policy.md), point 4

## Context

[ADR 0018](0018-supply-chain-policy.md), point 4, ran eight file-hygiene hooks from pre-commit-hooks 6.0.0, installed with pip from PyPI. That kept a second package registry in the chain:

- pip downloaded packages, plus an unpinned setuptools for pre-commit's placeholder package, protected only by the 3-day cutoff of `PIP_UPLOADED_PRIOR_TO`;
- PyPI lets a maintainer add files to a published version, and pre-commit cannot pin dependencies by hash;
- `end-of-file-fixer` opens every file for writing, so it fails in the assistant's sandbox, where `.claude/` is read-only, and had to be skipped there.

The other hooks (gitleaks, actionlint, zizmor) already ran binaries pinned by mise.

## Decision

Every hook runs a tool pinned by mise, a script in `scripts/hooks/`, or pre-commit's built-in `pygrep`. No hook installs anything when it runs.

| Old hook (pre-commit-hooks 6.0.0) | Replacement |
| --- | --- |
| trailing-whitespace, end-of-file-fixer | [editorconfig-checker](https://github.com/editorconfig-checker/editorconfig-checker) 4.0.2, which checks what `.editorconfig` declares: trailing whitespace, final newline, line endings and charset |
| check-yaml | [yq](https://github.com/mikefarah/yq) 4.54.1 |
| check-json | `scripts/hooks/check-json.py`, Python standard library only |
| check-toml | `scripts/hooks/check-toml.sh`, with `tomljson` from [go-toml](https://github.com/pelletier/go-toml) 2.4.3 |
| check-merge-conflict, detect-private-key | `language: pygrep` with the upstream patterns |
| check-added-large-files | `scripts/hooks/check-large-files.sh`, same 500 KB limit |
| (new) | shellcheck on `scripts/`, because those scripts run on every commit |

Details:

- **The new hooks report; they do not fix.** A failing file is fixed by hand.
- **Indentation size is not checked** (`.editorconfig-checker.json`). The old hooks did not check it either, and the canonical `LICENSE` and Markdown lists would fail (tested). Turning it on is a separate decision.
- **editorconfig-checker's built-in exclusions are off** (`IgnoreDefaults`). By default it silently skips files such as `pnpm-lock.yaml`, `go.sum` and `*.svg`, which the old hooks checked (tested); pre-commit already passes it text files only.
- **Small differences from the old hooks:** `check-json.py` reads files as UTF-8, so it rejects a JSON file with a byte order mark (consistent with `charset = utf-8`); `check-large-files.sh` has no exception for Git LFS files, which the repository does not use.
- **detect-private-key stays next to gitleaks.** gitleaks only reports a complete key; the pygrep hook also flags a key header on its own. Its patterns are written as alternatives and character classes so that `.pre-commit-config.yaml` does not match itself.
- **JSON uses a Python script** because yq accepts duplicate keys (tested). The script uses only the standard library, runs isolated (`python3 -I`), and pre-commit already needs `python3`.
- **`PIP_UPLOADED_PRIOR_TO` stays** in `mise.toml` as a safety net: no hook installs Python packages today, but one added later would get the 3-day cutoff.

### Where a tool comes from: order of preference

1. **aqua with a signature or build provenance that mise verifies** (cosign, SLSA, GitHub artifact attestations).
2. **go: from source**, verified through proxy.golang.org and sum.golang.org, with the `install_env` of [ADR 0017](0017-mise-paranoid-toolchain.md).
3. **aqua with checksums only**, when neither is available.

Every tool in `mise.toml` on 2026-10-24:

| Tool | Backend | Level | Verification |
| --- | --- | --- | --- |
| Node.js | core | 1, not guaranteed | `SHASUMS256.txt` and its OpenPGP signature. mise's documentation says it checks the signature itself and that `node.gpg_verify` is on by default, but the installed mise reports the setting as not set and contains a "gpg signature not found, skipping verification" path. Until that is confirmed, treat it as level 3 on a machine without `gpg` ([issue #20](https://github.com/andresBR8/patchconi/issues/20)) |
| pnpm | aqua | 1 | GitHub artifact attestations |
| actionlint | aqua | 1 | Checksums and GitHub artifact attestations |
| zizmor | aqua | 1 | GitHub artifact attestations |
| yq | aqua | 1 | Checksums signed with cosign (`provenance = "cosign"` in `mise.lock`) |
| gitleaks | go: | 2 | sum.golang.org (see ADR 0017) |
| editorconfig-checker | go: | 2 | sum.golang.org. The release has a checksums file and an attestation that the release is immutable, not build provenance |
| tomljson (go-toml) | go: | 2 | sum.golang.org. The release binaries come with a checksums file only, without signature or attestation |
| Go | core | 3 | The `.sha256` file published next to the archive, on the same server |
| pre-commit | aqua | 3 | The asset digest that GitHub records; the release publishes no checksum file or attestation |
| shellcheck | aqua | 3 | The checksum recorded in `mise.lock`; the release publishes no checksum file or attestation, and it cannot be built with go: |

Go and pre-commit may be able to move up a level: issues [#18](https://github.com/andresBR8/patchconi/issues/18) and [#19](https://github.com/andresBR8/patchconi/issues/19).

## Alternatives considered

- **Keep pre-commit-hooks from PyPI** — keeps pip and PyPI in the chain, and the sandbox `SKIP`.
- **taplo for TOML** — its last release is from May 2025, with no checksums or signatures.
- **yq for TOML and JSON** — its documentation lists a TOML table it cannot parse yet, and it accepts duplicate keys in JSON.
- **yamllint, check-jsonschema** — Python packages from PyPI again.
- **jq for JSON** — accepts duplicate keys.
- **Drop detect-private-key and rely on gitleaks** — gitleaks misses a key header without the rest of the key.
- **editorconfig-checker and tomljson from aqua** — only checksums from the same release, which prove nothing against a compromised release (level 3, when level 2 is available).

## Consequences

- Positive: pip and PyPI leave the hook chain. Every hook runs a pinned, verified tool or a script reviewed in this repository.
- Positive: the hooks only read files, so they run unchanged in the assistant's sandbox; the `SKIP` is gone.
- Negative and trade-offs: nothing fixes files automatically any more.
- Negative and trade-offs: yq accepts duplicate keys in YAML. actionlint reports them in workflows (tested); other YAML files are not checked for them. Accepted for now: [issue #17](https://github.com/andresBR8/patchconi/issues/17), to be checked again when the schema validator is chosen in phase 1. Done in [ADR 0021](0021-json-schema-validator-jv.md): the `check-yaml-duplicates` hook.
- Negative and trade-offs: the first `mise install` compiles two more tools. Renovate may not find versions for the `go:` paths that point to a command inside a module (`.../cmd/...`); check the Dependency Dashboard after merging. Unlike gitleaks, their Renovate updates need no manual approval: Go verifies them through sum.golang.org and they carry no version in ldflags, so the 3-day delay and CI are enough.
- Negative and trade-offs: the hook scripts and `check-json.py` use the system `bash` and `python3`, which are not pinned.
- Follow-ups:
  - The 500 KB limit needs a review in phase 2: `pnpm-lock.yaml` will grow past it once the applications have dependencies.
  - Verify the Go toolchain through sum.golang.org (`golang.org/toolchain`) instead of a checksum from the same server: [issue #18](https://github.com/andresBR8/patchconi/issues/18).
  - Check whether pre-commit's PyPI releases carry attestations that mise could verify: [issue #19](https://github.com/andresBR8/patchconi/issues/19).
