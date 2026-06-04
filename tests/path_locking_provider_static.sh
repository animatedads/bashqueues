#!/usr/bin/env bash
set -euo pipefail

provider="providers.d/path_lock/path_lock_provider.sh"
fixture="providers.d/path_lock/path_lock_fixture.py"
[[ -f "$provider" ]] || { echo "missing $provider" >&2; exit 1; }
[[ -f "$fixture" ]] || { echo "missing $fixture" >&2; exit 1; }

grep -q 'Fixture-only' "$provider"
grep -q 'does not open' "$provider"
grep -q 'exec python3 "$_fixture" evaluate' "$provider"

grep -q 'SCHEMA = "queuebash.path_lock.decision.v1"' "$fixture"
grep -q 'symlink_denied' "$fixture"
grep -q 'magiclink_denied' "$fixture"
grep -q 'parent_identity_mismatch' "$fixture"
grep -q 'final_identity_mismatch' "$fixture"
grep -q 'replace_cross_directory_denied' "$fixture"
grep -q 'shared_tmp_high_risk_denied' "$fixture"

if grep -Eq '\b(chmod|chown|unlink|rename|rmdir|mkdir|symlink|link)\s*\(' "$fixture"; then
  echo "fixture helper must not perform filesystem mutation primitives" >&2
  exit 1
fi
if grep -Eq '\b(os\.open|Path\([^)]*\)\.open)\b' "$fixture"; then
  echo "fixture helper must not open target paths through OS open helpers" >&2
  exit 1
fi

if grep -R "secret_value_included.*true" providers.d/path_lock tests/fixtures/path_lock >/dev/null 2>&1; then
  echo "path-lock provider evidence must remain redacted" >&2
  exit 1
fi

echo "PASS path_locking_provider_static"
