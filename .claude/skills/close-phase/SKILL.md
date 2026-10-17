---
name: close-phase
description: Walks the Definition of Done for a phase and refuses to close it while anything is missing.
disable-model-invocation: true
argument-hint: "[phase number]"
allowed-tools: Bash(git status *) Bash(git log *) Bash(tail *) Bash(true)
---

## Current state

- Branch and status: !`git status --short --branch || true`
- Recent commits: !`git log --oneline -15 || true`
- Last progress lines: !`tail -n 8 docs/aprendizaje/PROGRESO.md || true`

## Task

Close phase $ARGUMENTS only if every point of the Definition of Done in `docs/aprendizaje/PLAN.md` holds. Read that section and the phase's exit criteria first.

For each point, collect the evidence yourself (run the command, open the file, ask the maintainer for what you cannot see, such as CI status) and fill this table:

| # | Point | ✅/❌ | Evidence |
| --- | --- | --- | --- |

The points:

1. Every exit criterion of the phase demonstrated with a command or a screenshot.
2. CI green on `main`.
3. `pre-commit run --all-files` clean and no secrets in the whole history (`gitleaks git`).
4. New tests for new behavior; nothing disabled without an open issue.
5. Docs up to date: README if usage changed, one ADR per decision, new concepts explained in `docs/aprendizaje/conceptos/`.
6. Review done by the `reviewer` subagent, the review chat and the maintainer; findings fixed or turned into issues.
7. The maintainer can explain every piece: list the 3–5 key concepts of the phase and ask the maintainer to explain two of them in their own words before marking this point.
8. `PROGRESO.md` updated and the phase milestone closed on GitHub.

If any point is ❌, stop: list what is missing as concrete next steps and do not declare the phase closed. If everything is ✅, draft the PROGRESO line and a closing summary in Spanish for the maintainer to review.
