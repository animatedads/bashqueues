#!/usr/bin/env bash
# bashqueues distributed framework provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_DISTRIBUTED_FRAMEWORK_FIXTURE_DIR:-}"
_live="${QUEUEBASH_DISTRIBUTED_FRAMEWORK_LIVE_CHECKS:-0}"

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
  "provider_family": "distributed_framework",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "remediation_hint": "Provide QUEUEBASH_DISTRIBUTED_FRAMEWORK_FIXTURE_DIR fixtures for contract tests. Live reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/distributed_framework/distributed_framework_provider.sh detect
  providers.d/distributed_framework/distributed_framework_provider.sh runtime explain
  providers.d/distributed_framework/distributed_framework_provider.sh cluster explain
  providers.d/distributed_framework/distributed_framework_provider.sh data-access explain
  providers.d/distributed_framework/distributed_framework_provider.sh governance explain

Default mode is fixture-only via QUEUEBASH_DISTRIBUTED_FRAMEWORK_FIXTURE_DIR.
Distributed-framework facts are advisory only. This helper never starts clusters, submits jobs, scales workers, or changes queue scheduling.
It does not return shell commands or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.distributed_framework.detect.v1 detect missing_fixture_detect_json ;;
  "runtime explain") _json_file runtime.json || _fail_json queuebash.distributed_framework.runtime.v1 runtime missing_fixture_runtime_json ;;
  "cluster explain") _json_file cluster.json || _fail_json queuebash.distributed_framework.cluster.v1 cluster missing_fixture_cluster_json ;;
  "data-access explain") _json_file data-access.json || _fail_json queuebash.distributed_framework.data_access.v1 data_access missing_fixture_data_access_json ;;
  "governance explain") _json_file governance.json || _fail_json queuebash.distributed_framework.governance.v1 governance missing_fixture_governance_json ;;
  *) echo "ERROR: unsupported distributed framework provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
