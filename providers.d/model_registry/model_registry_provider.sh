#!/usr/bin/env bash
# bashqueues model registry provider contract helper.
# Fixture/read-only facts only. No inference, deployment, mutation, or ask-provider runtime changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_MODEL_REGISTRY_FIXTURE_DIR:-}"
_live="${QUEUEBASH_MODEL_REGISTRY_LIVE_CHECKS:-0}"

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
  "provider_family": "model_registry",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "remediation_hint": "Provide QUEUEBASH_MODEL_REGISTRY_FIXTURE_DIR fixtures for contract tests. Live registry reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/model_registry/model_registry_provider.sh detect
  providers.d/model_registry/model_registry_provider.sh catalog explain
  providers.d/model_registry/model_registry_provider.sh model explain
  providers.d/model_registry/model_registry_provider.sh governance explain

Default mode is fixture-only via QUEUEBASH_MODEL_REGISTRY_FIXTURE_DIR.
This helper exposes normalized model-registry facts only. It does not call
inference APIs, deploy models, store tokens, choose queue ask providers, or
provision registry services.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.model_registry.detect.v1 detect missing_fixture_detect_json ;;
  "catalog explain") _json_file catalog.json || _fail_json queuebash.model_registry.catalog.v1 catalog missing_fixture_catalog_json ;;
  "model explain") _json_file model.json || _fail_json queuebash.model_registry.model.v1 model missing_fixture_model_json ;;
  "governance explain") _json_file governance.json || _fail_json queuebash.model_registry.governance.v1 governance missing_fixture_governance_json ;;
  *) echo "ERROR: unsupported model registry provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
