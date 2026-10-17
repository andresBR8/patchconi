---
paths:
  - "docs/**"
  - "**/*.md"
---

# Documentation rules

- Product docs (README, `docs/user/`, `docs/architecture.md`, ADRs, the platform contract) are in English and written for someone who has never seen the project.
- `docs/aprendizaje/` is in Spanish. It explains concepts and decisions so the maintainer can defend them in an interview.
- Every command in a doc has been run and works as written. If something must be replaced, say what and with what.
- Docs change in the same commit as the behavior they describe.
- Never put environment-specific values (IPs, domains, hostnames, tokens) in any doc.
