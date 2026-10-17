---
paths:
  - "apps/**"
  - "agent/**"
  - "packages/**"
  - "deploy/**"
---

# Security rules for product code

- Validate every external input at the boundary (HTTP bodies, query params, headers, agent reports, environment variables) with an explicit schema. Reject unknown fields.
- Put limits on everything that comes from outside: request size, report size, rate per token and per IP, page size.
- Agent tokens and session secrets are stored only as hashes, compared in constant time and never logged.
- Authorization is checked server-side on every route. Default deny.
- No string-built SQL: use Drizzle's query builder or parameterized `sql` templates.
- Logs are structured JSON and never contain tokens, passwords, cookies or full agent reports.
- The agent is read-only: it never runs a package manager in write mode, never executes commands received from the server and runs as an unprivileged user.
- Errors returned to clients carry no stack traces or internal details.
- Any new dependency, permission or outbound network call is named explicitly in the plan for the step.
