# 0003. Web UI with React and Vite, served as static files by unprivileged nginx

- Status: Accepted
- Date: 2026-10-16
- Deciders: maintainer

## Context

The web UI is a dashboard behind a login: fleet overview, host details, enrollment, settings. It has no public, indexable pages. It must be cheap to run on small clusters and easy to secure.

## Decision

A single-page application built with React and Vite. The build output is static files served by nginx running as a non-root user. The SPA calls `/api` on the same origin.

A dashboard behind a login does not need server-side rendering, and without SSR there is no extra Node.js process to run, patch and scale on small clusters.

## Alternatives considered

- **Next.js** — familiar, but its main strengths (SSR, server components, SEO) bring little to a dashboard behind a login, and it adds a Node.js runtime to every deployment.

## Consequences

- Positive: a small, simple runtime (static files and nginx) with a minimal attack surface.
- Positive: same-origin `/api` avoids CORS configuration.
- Negative and trade-offs: all rendering happens in the browser; the first load downloads the application bundle.
- Follow-ups: the nginx image follows the platform contract (non-root, read-only root filesystem) when it is written in phase 2.
