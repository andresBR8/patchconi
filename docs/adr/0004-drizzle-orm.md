# 0004. Drizzle as the ORM

- Status: Accepted
- Date: 2026-10-16
- Deciders: maintainer

## Context

The API is the only component that talks to PostgreSQL. Its core queries are about time and aggregates: how long a host has had pending updates, how many hosts break the policy, history per host. Migrations must be reviewable and run as a separate step (platform contract, section 5).

## Decision

[Drizzle](https://orm.drizzle.team/) for schema, queries and migrations.

- SQL stays explicit: age and aggregate queries are written close to the SQL they produce, so they can be read and tuned.
- Migrations are plain SQL files that are reviewed like any other change.

## Alternatives considered

- **Prisma** — its query API hides the SQL, which makes age and aggregate queries harder to express and tune. (Prisma Migrate also generates SQL migrations, so migrations are not the difference.)

## Consequences

- Positive: predictable SQL and reviewable migrations.
- Positive: no string-built SQL: the query builder or parameterized `sql` templates.
- Negative and trade-offs: more SQL knowledge is needed than with a higher-level ORM.
- Follow-ups: schema and migrations as a separate command in phase 3.
