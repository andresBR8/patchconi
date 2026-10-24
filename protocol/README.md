# Agent protocol

The contract between the agent and the server, kept apart from both because the API (TypeScript) and the agent (Go) read the same files ([ADR 0022](../docs/adr/0022-report-schema-first.md)). The rules behind it: [docs/product/protocol.md](../docs/product/protocol.md).

| Path | What it holds |
| --- | --- |
| `v1/report.schema.json` | JSON Schema 2020-12 of the agent report: the source of truth. |
| `v1/openapi.yaml` | OpenAPI 3.1 draft of `POST /api/v1/agent/reports`. |
| `v1/examples/` | Valid reports built from the captures, and `invalid/` reports that must fail. |
| `captures/` | Real `apt` and `dnf` output, and the scripts that capture it. |
| `vendor/` | The OpenAPI 3.1 schema, copied with its source and checksum. |

Nothing here has a remote `$ref`, so validation works offline. The `check-protocol` pre-commit hook validates everything with jv ([ADR 0021](../docs/adr/0021-json-schema-validator-jv.md)) when a file here changes. To run it by hand:

```sh
mise exec -- pre-commit run check-protocol --all-files
```
