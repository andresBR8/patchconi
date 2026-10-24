# Vendored schemas

Copies of third-party schemas, so that the protocol is validated offline and against a known version. Each file is kept byte for byte as downloaded; its checksum below is checked by hand when it is replaced.

| File | Source | SHA-256 | License |
| --- | --- | --- | --- |
| `openapi-3.1-schema-2026-08-03.json` | <https://spec.openapis.org/oas/3.1/schema/2026-08-03> (OpenAPI 3.1 documents, without Schema Object validation), downloaded 2026-10-25 | `59f106413cb48c31299f96f024c938d3628aed6cd02cd14bcfb2fcaae7a130b6` | Apache-2.0, [OpenAPI Initiative](https://github.com/OAI/OpenAPI-Specification) |

This schema checks the structure of `protocol/v1/openapi.yaml`, not the JSON Schemas inside it: those point at `report.schema.json`, which jv checks against the 2020-12 metaschema built into it. It has no remote `$ref`.

To replace it with a newer release, listed at <https://spec.openapis.org/oas/>:

```sh
curl -sS -o protocol/vendor/openapi-3.1-schema-<date>.json https://spec.openapis.org/oas/3.1/schema/<date>
sha256sum protocol/vendor/openapi-3.1-schema-<date>.json
```

Then update this table and `scripts/hooks/check-protocol.sh`.
