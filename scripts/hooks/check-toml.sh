#!/usr/bin/env bash
# Fails if any of the given files is not valid TOML. Used by pre-commit.
# tomljson (pinned in mise.toml) only parses its first argument, so each file
# is checked on its own. It reads the files and never writes them.
set -euo pipefail

status=0
for file in "$@"; do
  if ! tomljson "$file" >/dev/null; then
    echo "$file: invalid TOML" >&2
    status=1
  fi
done
exit "$status"
