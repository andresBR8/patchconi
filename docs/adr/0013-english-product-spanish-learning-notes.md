# 0013. English for the product; Spanish for the maintainer's learning notes

- Status: Accepted
- Date: 2026-10-16
- Deciders: maintainer

## Context

PatchConi is public and meant for an international audience. It is also the maintainer's learning project: understanding every piece is a goal in itself, and the maintainer's first language is Spanish.

## Decision

- English for the product: code, identifiers, API, commit messages, README, ADRs and product documentation.
- Spanish for `docs/aprendizaje/`: learning notes, runbooks, the project plan and the progress log.

The product is public and international; the learning notes are in the maintainer's language so learning goes faster.

## Alternatives considered

- **Everything in Spanish** — would shrink the audience of a public product and make outside contributions harder.

## Consequences

- Positive: the product reads naturally to an international audience; the notes serve their purpose for the maintainer.
- Negative and trade-offs: two languages in one repository; some explanations exist in both an ADR (English) and a note (Spanish).
- Follow-ups: none.
