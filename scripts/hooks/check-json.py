#!/usr/bin/env python3
"""Fail if any of the given files is not valid JSON or repeats a key.

Used by pre-commit. Only the standard library: no package is installed.
Duplicate keys are valid for most JSON parsers, which silently keep the last
value, so they are rejected here as check-json in pre-commit-hooks did.
"""

import json
import sys


def reject_duplicates(pairs):
    seen = set()
    for key, _ in pairs:
        if key in seen:
            raise ValueError(f"duplicate key {key!r}")
        seen.add(key)
    return dict(pairs)


def main(paths):
    status = 0
    for path in paths:
        try:
            with open(path, encoding="utf-8") as f:
                json.load(f, object_pairs_hook=reject_duplicates)
        except (OSError, UnicodeDecodeError, ValueError) as error:
            print(f"{path}: {error}", file=sys.stderr)
            status = 1
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
