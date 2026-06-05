#!/usr/bin/env bash
# bashqueues backup service provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_BACKUP_SERVICE_FIXTURE_DIR:-}"
_live="${QUEUEBASH_BACKUP_SERVICE_LIVE_CHECKS:-0}"

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
  "provider_family": "backup_service",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_BACKUP_SERVICE_FIXTURE_DIR fixtures for contract tests. Live backup service reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/backup_service/backup_service_provider.sh detect
  providers.d/backup_service/backup_service_provider.sh policy explain
  providers.d/backup_service/backup_service_provider.sh repository explain
  providers.d/backup_service/backup_service_provider.sh schedule explain
  providers.d/backup_service/backup_service_provider.sh recovery_point explain

Default mode is fixture-only via QUEUEBASH_BACKUP_SERVICE_FIXTURE_DIR.
This helper exposes normalized backup service facts only. It does not
make live service calls, mutate provider state, provision services, return
commands for execution, or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.backup_service.detect.v1 detect missing_fixture_detect_json ;;
  "policy explain") _json_file policy.json || _fail_json queuebash.backup_service.policy.v1 policy missing_fixture_policy_json ;;
  "repository explain") _json_file repository.json || _fail_json queuebash.backup_service.repository.v1 repository missing_fixture_repository_json ;;
  "schedule explain") _json_file schedule.json || _fail_json queuebash.backup_service.schedule.v1 schedule missing_fixture_schedule_json ;;
  "recovery_point explain") _json_file recovery_point.json || _fail_json queuebash.backup_service.recovery_point.v1 recovery_point missing_fixture_recovery_point_json ;;
  *) echo "ERROR: unsupported backup service provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
