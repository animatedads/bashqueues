#!/usr/bin/env bash
# bashqueues key value store provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_KEY_VALUE_STORE_FIXTURE_DIR:-}"
_live="${QUEUEBASH_KEY_VALUE_STORE_LIVE_CHECKS:-0}"

_json_file() {
  local name="$1"
  [[ -n "$_fixture_dir" && -f "$_fixture_dir/$name" ]] && cat "$_fixture_dir/$name" && return 0
  return 1
}

_fail_json() {
  local schema="$1" check="$2" reason="$3"
  /usr/bin/python3 - "$schema" "$check" "$reason" <<'PYFAIL'
import json, sys
schema, check, reason = sys.argv[1:4]
print(json.dumps({
  "schema": schema,
  "provider_family": "key_value_store",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_KEY_VALUE_STORE_FIXTURE_DIR fixtures for contract tests. Live key value store reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/key_value_store/key_value_store_provider.sh detect
  providers.d/key_value_store/key_value_store_provider.sh table explain
  providers.d/key_value_store/key_value_store_provider.sh capacity explain
  providers.d/key_value_store/key_value_store_provider.sh policy explain
  providers.d/key_value_store/key_value_store_provider.sh backup explain

Default mode is fixture-only via QUEUEBASH_KEY_VALUE_STORE_FIXTURE_DIR.
This helper exposes normalized key value store facts only. It does not
make live service calls, mutate provider state, provision services, return
commands for execution, or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.key_value_store.detect.v1 detect missing_fixture_detect_json ;;
  "table explain") _json_file table.json || _fail_json queuebash.key_value_store.table.v1 table missing_fixture_table_json ;;
  "capacity explain") _json_file capacity.json || _fail_json queuebash.key_value_store.capacity.v1 capacity missing_fixture_capacity_json ;;
  "policy explain") _json_file policy.json || _fail_json queuebash.key_value_store.policy.v1 policy missing_fixture_policy_json ;;
  "backup explain") _json_file backup.json || _fail_json queuebash.key_value_store.backup.v1 backup missing_fixture_backup_json ;;
  *) echo "ERROR: unsupported key value store provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
