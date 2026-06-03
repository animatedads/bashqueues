#!/usr/bin/env bash
# bashqueues data lake provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_DATA_LAKE_FIXTURE_DIR:-}"
_live="${QUEUEBASH_DATA_LAKE_LIVE_CHECKS:-0}"

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
  "provider_family": "data_lake",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "remediation_hint": "Provide QUEUEBASH_DATA_LAKE_FIXTURE_DIR fixtures for contract tests. Live reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/data_lake/data_lake_provider.sh detect 
  providers.d/data_lake/data_lake_provider.sh catalog explain
  providers.d/data_lake/data_lake_provider.sh dataset explain
  providers.d/data_lake/data_lake_provider.sh governance explain
  providers.d/data_lake/data_lake_provider.sh retention explain

Default mode is fixture-only via QUEUEBASH_DATA_LAKE_FIXTURE_DIR.
This helper exposes normalized data lake facts only. It does not make live
service calls, create resources, mutate data, return shell commands, or alter
queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.data_lake.detect.v1 detect missing_fixture_detect_json ;;
  "catalog explain") _json_file catalog.json || _fail_json queuebash.data_lake.catalog.v1 catalog missing_fixture_catalog_json ;;
  "dataset explain") _json_file dataset.json || _fail_json queuebash.data_lake.dataset.v1 dataset missing_fixture_dataset_json ;;
  "governance explain") _json_file governance.json || _fail_json queuebash.data_lake.governance.v1 governance missing_fixture_governance_json ;;
  "retention explain") _json_file retention.json || _fail_json queuebash.data_lake.retention.v1 retention missing_fixture_retention_json ;;
  *) echo "ERROR: unsupported data lake provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
