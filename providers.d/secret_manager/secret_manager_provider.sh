#!/usr/bin/env bash
# bashqueues secret manager provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_SECRET_MANAGER_FIXTURE_DIR:-}"
_live="${QUEUEBASH_SECRET_MANAGER_LIVE_CHECKS:-0}"

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
  "provider_family": "secret_manager",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "remediation_hint": "Provide QUEUEBASH_SECRET_MANAGER_FIXTURE_DIR fixtures for contract tests. Live reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/secret_manager/secret_manager_provider.sh detect
  providers.d/secret_manager/secret_manager_provider.sh secret explain
  providers.d/secret_manager/secret_manager_provider.sh rotation explain
  providers.d/secret_manager/secret_manager_provider.sh access-policy explain
  providers.d/secret_manager/secret_manager_provider.sh audit explain

Default mode is fixture-only via QUEUEBASH_SECRET_MANAGER_FIXTURE_DIR.
This helper exposes normalized secret manager facts only. It does not make live
service calls, create resources, mutate data, return shell commands, or alter
queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.secret_manager.detect.v1 detect missing_fixture_detect_json ;;
  "secret explain") _json_file secret.json || _fail_json queuebash.secret_manager.secret.v1 secret missing_fixture_secret_json ;;
  "rotation explain") _json_file rotation.json || _fail_json queuebash.secret_manager.rotation.v1 rotation missing_fixture_rotation_json ;;
  "access-policy explain") _json_file access-policy.json || _fail_json queuebash.secret_manager.access_policy.v1 access_policy missing_fixture_access_policy_json ;;
  "audit explain") _json_file audit.json || _fail_json queuebash.secret_manager.audit.v1 audit missing_fixture_audit_json ;;
  *) echo "ERROR: unsupported secret manager provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
