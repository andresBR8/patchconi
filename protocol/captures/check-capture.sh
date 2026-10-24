#!/usr/bin/env bash
# Check captured output before it is committed. Read-only: it never changes
# the files it checks.
#
# Usage: protocol/captures/check-capture.sh [--deny-patterns FILE] PATH...
#
# PATH is a capture file or a directory of them (searched recursively).
#
# --deny-patterns FILE: one fixed string per line (host names, domains,
#   addresses, user names...), matched case-insensitively; empty lines and
#   lines starting with # are ignored. The file must live outside this
#   repository, so that the patterns themselves are never committed.
#   Any match fails the check (exit 1).
#
# Without the option, and in addition to it, the script lists lines that
# look like IPv4 or MAC addresses or email addresses, for review by hand.
# They do not fail the check: package versions can look like addresses.

set -euo pipefail

usage() {
  echo "usage: $0 [--deny-patterns FILE] PATH..." >&2
  exit 2
}

deny=''
if [ "${1:-}" = --deny-patterns ]; then
  [ $# -ge 2 ] || usage
  deny=$2
  shift 2
fi
[ $# -ge 1 ] || usage

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
status=0

if [ -n "$deny" ]; then
  deny_abs=$(realpath "$deny")
  case $deny_abs in
    "$repo_root"/*)
      echo "the deny patterns file must be outside the repository: $deny" >&2
      exit 2
      ;;
  esac
  patterns=$(grep -v -E '^[[:space:]]*(#|$)' "$deny_abs" || true)
  if [ -z "$patterns" ]; then
    echo "no patterns in $deny" >&2
    exit 2
  fi
  if grep -r -n -i -F -f <(printf '%s\n' "$patterns") -- "$@"; then
    echo "FAIL: the lines above match a deny pattern" >&2
    status=1
  else
    echo "ok: no deny pattern matches" >&2
  fi
fi

review() {
  local label=$1 regex=$2 hits
  shift 2
  hits=$(grep -r -n -E -- "$regex" "$@" || true)
  if [ -n "$hits" ]; then
    echo "review ($label):" >&2
    printf '%s\n' "$hits" | head -n 50 >&2
  fi
}

review 'IPv4-like' '(^|[^0-9.])([0-9]{1,3}\.){3}[0-9]{1,3}([^0-9.]|$)' "$@"
review 'MAC-like' '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' "$@"
review 'email-like' '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$@"

exit "$status"
