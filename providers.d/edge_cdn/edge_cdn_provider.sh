#!/usr/bin/env bash
# bashqueues edge cdn provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_EDGE_CDN_FIXTURE_DIR:-}"
_live="${QUEUEBASH_EDGE_CDN_LIVE_CHECKS:-0}"

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
  "provider_family": "edge_cdn",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_EDGE_CDN_FIXTURE_DIR fixtures for contract tests. Live CDN reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/edge_cdn/edge_cdn_provider.sh detect
  providers.d/edge_cdn/edge_cdn_provider.sh distribution explain
  providers.d/edge_cdn/edge_cdn_provider.sh origin explain
  providers.d/edge_cdn/edge_cdn_provider.sh cache explain
  providers.d/edge_cdn/edge_cdn_provider.sh policy explain

Default mode is fixture-only via QUEUEBASH_EDGE_CDN_FIXTURE_DIR.
This helper exposes normalized edge cdn facts only. It does not
make live service calls, mutate provider state, provision services, return
commands for execution, or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.edge_cdn.detect.v1 detect missing_fixture_detect_json ;;
  "distribution explain") _json_file distribution.json || _fail_json queuebash.edge_cdn.distribution.v1 distribution missing_fixture_distribution_json ;;
  "origin explain") _json_file origin.json || _fail_json queuebash.edge_cdn.origin.v1 origin missing_fixture_origin_json ;;
  "cache explain") _json_file cache.json || _fail_json queuebash.edge_cdn.cache.v1 cache missing_fixture_cache_json ;;
  "policy explain") _json_file policy.json || _fail_json queuebash.edge_cdn.policy.v1 policy missing_fixture_policy_json ;;
  *) echo "ERROR: unsupported edge cdn provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
