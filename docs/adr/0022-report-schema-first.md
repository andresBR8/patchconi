# 0022. The agent report is schema-first: one hand-written JSON Schema for the API and the agent

- Status: Accepted
- Date: 2026-10-25
- Deciders: maintainer

## Context

[ADR 0008](0008-openapi-contract-checked-in-ci.md) has the API generate its OpenAPI document from the code. That fits the web UI, whose client is generated from it, and the API is the source of truth. It fits the agent report less well:

- The agent (Go, phase 5) is built after the API (TypeScript, phase 4), but its report has to be fixed now: the domain model already stores what it carries, and the captures were taken to design it.
- Two producers of the contract, a TypeScript validator and Go structs, drift unless both are checked against the same file.
- The rules that matter most are hard to get from code generation: unknown properties rejected everywhere, a `packages` section that is either the update lists or a parser error (AC-8.7), `esm_enabled` only on Ubuntu, size limits.

## Decision

`protocol/v1/report.schema.json`, a hand-written JSON Schema 2020-12 document, is the source of truth for the agent report.

- The API validates every report body with this file (phase 4). Its generated OpenAPI document must use this schema for the request body of `POST /api/v1/agent/reports`, and CI checks that it does.
- The agent's tests validate the reports it builds from the captured output with the same file (phase 5).
- Every example in `protocol/v1/examples/` states which capture it comes from. The invalid examples each list the error they must fail with. The `check-protocol` pre-commit hook checks both with jv ([ADR 0021](0021-json-schema-validator-jv.md)).
- `protocol/v1/openapi.yaml` is a hand-written draft of the endpoint: responses, problem details, authentication. It is checked against a vendored copy of the OpenAPI 3.1 schema, and is replaced by the generated document in phase 4.
- No remote `$ref`, in the schema or in the OpenAPI draft: validation works offline, and nothing outside the repository can change what is valid.
- Versioning: `schema_version` is `major.minor`; a minor version only adds optional properties; servers are upgraded before agents ([protocol](../product/protocol.md#versioning)).
- Identity and order travel in the schema, and the server applies them by fixed rules ([protocol](../product/protocol.md#ordering-and-identity)):
  - `agent_instance_id` and `sequence` order the reports, not the host clock.
  - The first `machine_fingerprint` a host sends becomes its known fingerprint. A report with another fingerprint, from any instance, is not applied and opens an alert: the token is being used from another machine.
  - A new instance with the known fingerprint is a reinstall and is applied.
  - A report from a superseded instance opens an alert at once, and so do two `sequence` regressions in a row.
  - A `report_id` names one body: the server keeps its SHA-256, so a repeat with the same body is answered `200` and one with a different body `409`.

## Alternatives considered

- **Generate the schema from the API code (ADR 0008 as it stands)** — the agent would wait for phase 4 to know its contract, and the strict rules above would depend on what the generator can express.
- **Generate Go and TypeScript types from the schema** — possible later. Validating against the schema at run time and in tests is needed anyway, and generated types do not enforce patterns, limits or the `if`/`then` rule.
- **Protocol Buffers or another IDL** — a second serialization and toolchain for one endpoint that sends JSON, and harder to read in a review.
- **Accept unknown properties** — lets agents upgrade first, but hides misspelled fields and contradicts AC-2.2.

## Consequences

- Positive: one file decides what is a valid report, for both sides, from phase 1. A contract change is one diff in review.
- Positive: the examples come from real output and are checked on every commit.
- Negative and trade-offs: the schema is written by hand, and the API's code must follow it; phase 4 has to wire the file into the generated OpenAPI document instead of deriving it.
- Negative and trade-offs: strict validation means an agent newer than its server cannot report until the server is upgraded.
- Negative and trade-offs: a reinstall that creates a new `/etc/machine-id` raises a false alarm; the administrator accepts it by rotating the token, which resets the known fingerprint. A clone that keeps the machine ID is not detected.
- Negative and trade-offs: jv downloads remote references (`$ref`, `$dynamicRef`, `$schema`), and has no option to stop it. The hook checks every reference with a small script, after JSON decoding, before it runs jv.
- Follow-ups: phase 4 validates with this file and checks the generated OpenAPI document against it in CI; phase 5 adds the agent's tests and the collectors described in the [protocol](../product/protocol.md).
- Refines [ADR 0008](0008-openapi-contract-checked-in-ci.md) for the agent report only; the rest of the API stays code-first.
