---
name: verify
description: Runs PatchConi's local checks (pre-commit with gitleaks, lint, typecheck, tests, Go tests) and reports the result. Use before every commit and whenever asked to check the repo.
---

Run the checks that exist in the repo right now, in this order, and stop at the first failure:

1. If `.pre-commit-config.yaml` exists: `mise exec -- pre-commit run --all-files`. `mise exec` runs the pre-commit pinned in `mise.toml`, whatever other pre-commit comes first on the `PATH`.
2. If a root `package.json` exists: `pnpm lint`, `pnpm typecheck` and `pnpm test`, only for the scripts it defines.
3. If `agent/go.mod` exists: `go vet ./...` and `go test ./...` inside `agent/`.

Report a short table: check · result · duration.

On failure, show the relevant part of the output, explain the cause and propose the fix. Do not commit, and never disable or skip a check to get green.

If none of these checks exist yet, say so and list which ones phase 0 still has to add.
