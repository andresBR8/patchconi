---
name: new-adr
description: Creates a new Architecture Decision Record in docs/adr with the next number and the project template. Use when a technical decision is taken or changed.
argument-hint: "[short title]"
---

1. List `docs/adr/` and take the next four-digit number, starting at `0001`.
2. Create `docs/adr/NNNN-<kebab-case-title>.md` from [template.md](template.md), in English.
3. Fill it from the conversation and `docs/aprendizaje/PLAN.md`: the context, the decision, the alternatives that were really considered (and why they lost) and the consequences, good and bad.
4. If it replaces an earlier ADR, set the old one's status to `Superseded by NNNN` and link both.
5. Add a row to `docs/adr/README.md` (create it if missing): number, title, status, date.
6. Show the result and wait for approval before committing.
