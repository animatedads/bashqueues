#!/usr/bin/env bash
# bashqueues feature store provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_FEATURE_STORE_FIXTURE_DIR:-}"
_live="${QUEUEBASH_FEATURE_STORE_LIVE_CHECKS:-0}"

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
  "provider_family": "feature_store",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "remediation_hint": "Provide QUEUEBASH_FEATURE_STORE_FIXTURE_DIR fixtures for contract tests. Live reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/feature_store/feature_store_provider.sh detect
  providers.d/feature_store/feature_store_provider.sh entity explain
  providers.d/feature_store/feature_store_provider.sh feature-view explain
  providers.d/feature_store/feature_store_provider.sh training-set explain
  providers.d/feature_store/feature_store_provider.sh lineage explain

Default mode is fixture-only via QUEUEBASH_FEATURE_STORE_FIXTURE_DIR.
This helper exposes normalized feature store facts only. It does not make live
service calls, create resources, mutate data, return shell commands, or alter
queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.feature_store.detect.v1 detect missing_fixture_detect_json ;;
  "entity explain") _json_file entity.json || _fail_json queuebash.feature_store.entity.v1 entity missing_fixture_entity_json ;;
  "feature-view explain") _json_file feature-view.json || _fail_json queuebash.feature_store.feature_view.v1 feature_view missing_fixture_feature_view_json ;;
  "training-set explain") _json_file training-set.json || _fail_json queuebash.feature_store.training_set.v1 training_set missing_fixture_training_set_json ;;
  "lineage explain") _json_file lineage.json || _fail_json queuebash.feature_store.lineage.v1 lineage missing_fixture_lineage_json ;;
  *) echo "ERROR: unsupported feature store provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
