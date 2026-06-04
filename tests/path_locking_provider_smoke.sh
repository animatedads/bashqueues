#!/usr/bin/env bash
set -euo pipefail

provider="providers.d/path_lock/path_lock_provider.sh"
run_case() {
  local fixture="$1" expected_allowed="$2" expected_reason="${3:-}"
  local out
  out="$($provider evaluate --fixture "$fixture" --json)"
  python3 - "$out" "$expected_allowed" "$expected_reason" <<'PY'
import json, sys
obj=json.loads(sys.argv[1])
expected_allowed=(sys.argv[2] == "true")
expected_reason=sys.argv[3]
assert obj.get("schema") == "queuebash.path_lock.decision.v1", obj
assert obj.get("allowed") is expected_allowed, obj
assert obj.get("redacted") is True, obj
assert obj.get("secret_value_included") is False, obj
if expected_reason:
    assert expected_reason in obj.get("reasons", []), obj
PY
}

run_case tests/fixtures/path_lock_provider/provider_symlink_pivot_blocked.json false symlink_denied
run_case tests/fixtures/path_lock_provider/provider_private_create_allowed.json true
run_case tests/fixtures/path_lock_provider/provider_replace_crossdir_blocked.json false replace_cross_directory_denied
run_case tests/fixtures/path_lock_provider/provider_shared_tmp_high_risk_blocked.json false shared_tmp_high_risk_denied
run_case tests/fixtures/path_lock_provider/provider_magiclink_blocked.json false magiclink_denied

echo "PASS path_locking_provider_smoke"
