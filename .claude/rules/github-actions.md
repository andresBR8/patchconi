---
paths:
  - ".github/**"
---

# GitHub Actions rules

- Pin every action to a full commit SHA with the version in a comment: `uses: owner/action@<40-char-sha> # vX.Y.Z`. Look the SHA up; never invent or guess it.
- Declare `permissions:` at workflow level, read-only by default. Grant write scopes per job, only when needed.
- Never use `pull_request_target`. Never interpolate untrusted input (`github.event.*`, branch names, PR titles) directly into `run:`; pass it through `env:`.
- Use `persist-credentials: false` on checkout unless the job has to push.
- Every workflow passes `actionlint`.
- Heavy jobs (distro matrix, kind, Playwright) run on pull requests to `main` and on `main`, not on every push.
