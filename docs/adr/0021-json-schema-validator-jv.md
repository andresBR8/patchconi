# 0021. JSON Schema validator: jv, built from source by mise

- Status: Accepted
- Date: 2026-10-24
- Deciders: maintainer

## Context

Phase 1 defines the agent report as a JSON Schema, and its exit criteria require the captured examples to validate against it. The check has to run in pre-commit and in CI, offline, with a tool pinned like every other hook ([ADR 0020](0020-pre-commit-hooks-as-pinned-binaries.md)).

A second gap was waiting for this choice: yq, the YAML syntax check, accepts duplicate keys ([issue #17](https://github.com/andresBR8/patchconi/issues/17)). In YAML a duplicate key silently overrides the first one. That matters for the OpenAPI draft and, from phase 2, for Kubernetes manifests.

## Decision

Use [jv](https://github.com/santhosh-tekuri/jsonschema/tree/master/cmd/jv) 0.7.0 (Apache-2.0), the command-line tool of the Go library `santhosh-tekuri/jsonschema/v6`, installed by mise with the `go:` backend. That is level 2 in ADR 0020's order: built from the code recorded by proxy.golang.org and verified by sum.golang.org, with the same `install_env` as the other `go:` tools.

- It supports draft 2020-12, the dialect of OpenAPI 3.1, and the earlier drafts. Format assertions (`--assert-format`) are opt-in.
- It reads schemas and instances in JSON or YAML. The metaschemas of the standard drafts are built in, so it validates offline (tested with an unreachable proxy).
- It parses YAML with `gopkg.in/yaml.v3`, which rejects a duplicate key at any depth (tested at the top level and nested). A new hook, `check-yaml-duplicates`, validates every YAML file against a schema that accepts anything (`scripts/hooks/any-document.schema.json`), so only the parser decides. yq stays as the syntax check, because it reads every document in a file.

Tested on 2026-10-24 with jv 0.7.0:

| Input | Result |
| --- | --- |
| YAML with a duplicate key, top level or nested | Rejected, with both line numbers |
| Second document of a multi-document YAML with a duplicate key | **Accepted**: only the first document is read |
| JSON with a duplicate key | **Accepted** |
| Every YAML file in the repository | Accepted (7 ms) |

## Alternatives considered

- **jv's release binaries** — they ship with md5 sums only, from the same release, and are built with a newer library (6.0.3). Level 3 with a weak hash, when level 2 is available.
- **sourcemeta/jsonschema** — a capable C++ tool, available through aqua. Its checksums are signed with OpenPGP, which mise does not verify, so it would be level 3 too. Its YAML duplicate key behavior was not tested.
- **check-jsonschema** — a Python package from PyPI, which ADR 0020 took out of the hook chain.
- **ajv-cli** — a Node package from npm; the command-line tool has had no release in years.
- **An OpenAPI linter (vacuum, Redocly, Spectral)** — lints style and conventions, which the hand-written draft does not need yet. Reconsidered in phase 4, when the API generates the OpenAPI document.

## Consequences

- Positive: one small, verified binary validates the protocol schema, its examples and the OpenAPI draft, and closes most of issue #17.
- Positive: the agent can use the same Go library in its tests (phase 5).
- Negative and trade-offs: `go install` builds jv with the library versions in its own `go.mod`: v6.0.1, while the library is at v6.0.3. The fixes since then are error locations, NaN and infinity numbers, the `email` format and number comparison in `const`/`enum`. None affects a schema built from strings, enums and integers. jv's last release is from June 2024.
- Negative and trade-offs: the second document of `pnpm-lock.yaml` is not checked for duplicate keys. pnpm writes it and nobody edits it by hand, so the risk is accepted.
- Negative and trade-offs: jv accepts duplicate keys in JSON. `check-json.py` already rejects them for every JSON file, protocol examples included.
- Negative and trade-offs: one more tool compiled on the first `mise install`. As with the other `go:` paths, Renovate may not find versions for a tool that is its own module under a subdirectory (tags `cmd/jv/vX.Y.Z`). Check the Dependency Dashboard after merging.
- Follow-ups: the protocol schema, examples and OpenAPI draft that use jv come in the next step (protocol v1).
