#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*" >&2; exit 1; }
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

for t in tests/command_catalog_json_full_surface_static.sh tests/command_catalog_json_full_surface_smoke.sh; do
  [[ -f "$t" ]] || fail "missing $t"
  if grep -Eq '0\.18\.13[0-8]' "$t"; then
    fail "$t pins a stale exact 0.18.13x version"
  fi
  bash -n "$t" || fail "$t syntax failed"
done
