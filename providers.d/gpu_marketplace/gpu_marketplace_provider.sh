#!/usr/bin/env bash
# bashqueues gpu marketplace provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_GPU_MARKETPLACE_FIXTURE_DIR:-}"
_live="${QUEUEBASH_GPU_MARKETPLACE_LIVE_CHECKS:-0}"

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
  "provider_family": "gpu_marketplace",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "remediation_hint": "Provide QUEUEBASH_GPU_MARKETPLACE_FIXTURE_DIR fixtures for contract tests. Live reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/gpu_marketplace/gpu_marketplace_provider.sh detect
  providers.d/gpu_marketplace/gpu_marketplace_provider.sh offer explain
  providers.d/gpu_marketplace/gpu_marketplace_provider.sh capability explain
  providers.d/gpu_marketplace/gpu_marketplace_provider.sh quota explain
  providers.d/gpu_marketplace/gpu_marketplace_provider.sh compliance explain

Default mode is fixture-only via QUEUEBASH_GPU_MARKETPLACE_FIXTURE_DIR.
GPU marketplace fixture facts are advisory only. Live marketplace reservations and spend actions are out of scope.
It does not return shell commands or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.gpu_marketplace.detect.v1 detect missing_fixture_detect_json ;;
  "offer explain") _json_file offer.json || _fail_json queuebash.gpu_marketplace.offer.v1 offer missing_fixture_offer_json ;;
  "capability explain") _json_file capability.json || _fail_json queuebash.gpu_marketplace.capability.v1 capability missing_fixture_capability_json ;;
  "quota explain") _json_file quota.json || _fail_json queuebash.gpu_marketplace.quota.v1 quota missing_fixture_quota_json ;;
  "compliance explain") _json_file compliance.json || _fail_json queuebash.gpu_marketplace.compliance.v1 compliance missing_fixture_compliance_json ;;
  *) echo "ERROR: unsupported gpu marketplace provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
