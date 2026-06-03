#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Resource code must not evaluate resource text.
if grep -nE '(^|[^A-Za-z_])eval[[:space:]].*resource|(^|[^A-Za-z_])source[[:space:]].*resource|(^|[^A-Za-z_])bash[[:space:]]+-c[[:space:]].*resource' queuebash.sh; then
  echo "unsafe resource evaluation pattern found" >&2
  exit 1
fi
# Resource payloads must use {{TOKEN}}, not shell expansions.
if grep -RInE '\$\{|\$\(|`' resources.d/display resources.d/xml resources.d/schemas 2>/dev/null; then
  echo "unsafe shell-style token found in resources" >&2
  exit 1
fi
