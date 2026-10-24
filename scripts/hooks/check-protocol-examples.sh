#!/usr/bin/env bash
# Checks the protocol v1 examples against the report schema. Used by
# pre-commit; reads files only.
#   - The schema compiles (jv checks it against the 2020-12 metaschema).
#   - Every report in examples/ is valid.
#   - Every report in examples/invalid/ is rejected with the error listed for
#     it in examples/invalid/expected.tsv, so that it fails for the reason it
#     was written for, not for an unrelated mistake.
# Formats are asserted (-f): a date such as 2026-13-03 is an error.
set -euo pipefail

dir=protocol/v1
schema="$dir/report.schema.json"
expected="$dir/examples/invalid/expected.tsv"
status=0

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
