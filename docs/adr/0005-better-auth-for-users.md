# 0005. Better Auth on PostgreSQL for user accounts

- Status: Accepted
- Date: 2026-10-16
- Deciders: maintainer

## Context

PatchConi needs user login with administrator and read-only roles and a first administrator created at startup. It is a self-hosted product: whoever installs it runs everything themselves.

## Decision

[Better Auth](https://www.better-auth.com/) as a library inside the API, storing users and sessions in the same PostgreSQL database. Email and password, session in a cookie.

A self-hosted product cannot require every installer to create an account in an external service just to log in.

## Alternatives considered

- **Supabase Auth** — ties every installation to an external service (or to running much of Supabase), which contradicts self-hosting.
- **Keycloak** — complete, but far too heavy for a small dashboard: another service with its own database, upgrades and configuration.

## Consequences

- Positive: no external dependency; one database to back up.
- Positive: authentication lives in the same codebase and is tested with it.
- Negative and trade-offs: login security (rate limiting, password hashing settings, session handling) is our responsibility.
- Follow-ups: login attempt limits and end-to-end auth tests in phase 3; OIDC/SSO after v0.1.0.
