#!/usr/bin/env bash
# Checks the protocol v1 files. Used by pre-commit; reads files only.
#   - No remote $ref: in the report schema every $ref points into the file
#     itself, and the OpenAPI document only points at local files.
#   - The OpenAPI document is valid against the vendored OpenAPI 3.1 schema.
#   - The report schema compiles (jv checks it against the 2020-12
#     metaschema built into it).
#   - Every report in examples/ is valid.
#   - Every report in examples/invalid/ is rejected with the error listed for
#     it in examples/invalid/expected.tsv, so that it fails for the reason it
#     was written for, not for an unrelated mistake.
# Formats are asserted (-f): a date such as 2026-13-03 is an error.
set -euo pipefail

dir=protocol/v1
schema="$dir/report.schema.json"
openapi="$dir/openapi.yaml"
oas_schema=protocol/vendor/openapi-3.1-schema-2026-08-03.json
expected="$dir/examples/invalid/expected.tsv"
status=0

if grep -n -E '"[$]ref": *"[^#]' "$schema" >&2; then
  echo "$schema: every \$ref must start with #" >&2
  status=1
fi
if grep -n -E '[$]ref: *"?([A-Za-z][A-Za-z0-9+.-]*:|//)' "$openapi" >&2; then
  echo "$openapi: no remote \$ref" >&2
  status=1
fi
# jv downloads remote references, so it must not run on such a file.
[ "$status" -eq 0 ] || exit "$status"

if ! out=$(jv -f "$oas_schema" "$openapi" 2>&1); then
  printf '%s\n' "$out" >&2
  echo "$openapi: must be a valid OpenAPI 3.1 document" >&2
  status=1
fi

for file in "$dir"/examples/*.json; do
  if ! out=$(jv -f "$schema" "$file" 2>&1); then
    printf '%s\n' "$out" >&2
    echo "$file: must be valid" >&2
    status=1
  fi
done

listed=()
while IFS=$'\t' read -r name error _; do
  case $name in '' | '#'*) continue ;; esac
  listed+=("$name")
  file="$dir/examples/invalid/$name"
  if [ ! -f "$file" ]; then
    echo "$expected: $name does not exist" >&2
    status=1
  elif out=$(jv -f "$schema" "$file" 2>&1); then
    echo "$file: must be rejected" >&2
    status=1
  elif ! grep -q -F -- "- at $error" <<<"$out"; then
    printf '%s\n' "$out" >&2
    echo "$file: rejected, but not with: $error" >&2
    status=1
  fi
done <"$expected"

for file in "$dir"/examples/invalid/*.json; do
  name=${file##*/}
  case " ${listed[*]} " in
    *" $name "*) ;;
    *)
      echo "$file: not listed in $expected" >&2
      status=1
      ;;
  esac
done

exit "$status"
