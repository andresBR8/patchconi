"""Fails if a JSON Schema or OpenAPI document could make jv fetch a URL.

Usage: python3 -I check-local-refs.py [--allow-files] FILE...

FILE is JSON; "-" reads standard input (the OpenAPI YAML, converted to JSON
by yq). jv downloads any remote $ref, $dynamicRef or $schema it meets, so
before jv runs, every one of them must be local:
  - $ref and $dynamicRef start with "#" (inside the document). With
    --allow-files they may also be a relative path in the same directory,
    starting with "./", without "..".
  - $schema is the JSON Schema 2020-12 URL, which jv has built in.
The keys are read after JSON decoding, so escapes such as "\\u0024ref" or
extra spaces do not hide them. Reads its inputs only.
"""

import json
import sys

DIALECT = "https://json-schema.org/draft/2020-12/schema"

# Keywords whose value maps names to schemas: a key there is a property or
# definition name (the OpenAPI schema has a property called "$ref"), not a
# keyword.
NAME_MAPS = ("properties", "patternProperties", "$defs", "definitions", "dependentSchemas")


def local(value, allow_files):
    if not isinstance(value, str):
        return False
    if value.startswith("#"):
        return True
    return (
        allow_files
        and value.startswith("./")
        and ".." not in value
        and ":" not in value
        and "//" not in value[2:]
    )


def walk(node, path, allow_files, errors, names=False):
    if isinstance(node, dict):
        for key, value in node.items():
            where = f"{path}/{key}"
            if names:
                walk(value, where, allow_files, errors)
                continue
            if key in ("$ref", "$dynamicRef") and not local(value, allow_files):
                errors.append(f"{where}: {value!r} is not a local reference")
            elif key == "$schema" and value != DIALECT:
                errors.append(f"{where}: {value!r} is not {DIALECT}")
            walk(value, where, allow_files, errors, key in NAME_MAPS)
    elif isinstance(node, list):
        for i, value in enumerate(node):
            walk(value, f"{path}/{i}", allow_files, errors)


def main(argv):
    allow_files = False
    if argv and argv[0] == "--allow-files":
        allow_files = True
        argv = argv[1:]
    status = 0
    for name in argv:
        try:
            if name == "-":
                doc = json.load(sys.stdin)
            else:
                with open(name, encoding="utf-8") as f:
                    doc = json.load(f)
        except (OSError, ValueError) as e:
            print(f"{name}: {e}", file=sys.stderr)
            status = 1
            continue
        errors = []
        walk(doc, "", allow_files, errors)
        for error in errors:
            print(f"{name}: {error}", file=sys.stderr)
        if errors:
            status = 1
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
