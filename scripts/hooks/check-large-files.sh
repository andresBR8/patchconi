#!/usr/bin/env bash
# Fails if any of the given files is larger than 500 KB, the default limit of
# check-added-large-files in pre-commit-hooks. Used by pre-commit on every file
# it passes, not only on newly added ones, so a tracked file that grows is also
# caught.
set -euo pipefail

max_kb=500
status=0
for file in "$@"; do
  # A file that cannot be read fails the hook without stopping the loop.
  if ! count=$(wc -c <"$file"); then
    status=1
    continue
  fi
  # wc -c prints leading spaces on macOS; the arithmetic expansion drops them.
  bytes=$((count))
  # Rounded up, as in pre-commit-hooks.
  kb=$(((bytes + 1023) / 1024))
  if [ "$kb" -gt "$max_kb" ]; then
    echo "$file ($kb KB) exceeds $max_kb KB." >&2
    status=1
  fi
done
exit "$status"
