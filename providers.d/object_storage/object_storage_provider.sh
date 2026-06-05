#!/usr/bin/env bash
# bashqueues object storage provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_OBJECT_STORAGE_FIXTURE_DIR:-}"
_live="${QUEUEBASH_OBJECT_STORAGE_LIVE_CHECKS:-0}"

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
  "provider_family": "object_storage",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_OBJECT_STORAGE_FIXTURE_DIR fixtures for contract tests. Live object storage reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/object_storage/object_storage_provider.sh detect
  providers.d/object_storage/object_storage_provider.sh bucket explain
  providers.d/object_storage/object_storage_provider.sh object explain
  providers.d/object_storage/object_storage_provider.sh retention explain
  providers.d/object_storage/object_storage_provider.sh policy explain

Default mode is fixture-only via QUEUEBASH_OBJECT_STORAGE_FIXTURE_DIR.
This helper exposes normalized object storage facts only. It does not
make live service calls, mutate provider state, provision services, return
commands for execution, or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.object_storage.detect.v1 detect missing_fixture_detect_json ;;
  "bucket explain") _json_file bucket.json || _fail_json queuebash.object_storage.bucket.v1 bucket missing_fixture_bucket_json ;;
  "object explain") _json_file object.json || _fail_json queuebash.object_storage.object.v1 object missing_fixture_object_json ;;
  "retention explain") _json_file retention.json || _fail_json queuebash.object_storage.retention.v1 retention missing_fixture_retention_json ;;
  "policy explain") _json_file policy.json || _fail_json queuebash.object_storage.policy.v1 policy missing_fixture_policy_json ;;
  *) echo "ERROR: unsupported object storage provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
