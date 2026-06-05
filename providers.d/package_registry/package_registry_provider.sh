#!/usr/bin/env bash
# bashqueues package registry provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_PACKAGE_REGISTRY_FIXTURE_DIR:-}"
_live="${QUEUEBASH_PACKAGE_REGISTRY_LIVE_CHECKS:-0}"

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
  "provider_family": "package_registry",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_PACKAGE_REGISTRY_FIXTURE_DIR fixtures for contract tests. Live package registry reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/package_registry/package_registry_provider.sh detect
  providers.d/package_registry/package_registry_provider.sh repository explain
  providers.d/package_registry/package_registry_provider.sh package explain
  providers.d/package_registry/package_registry_provider.sh provenance explain
  providers.d/package_registry/package_registry_provider.sh policy explain

Default mode is fixture-only via QUEUEBASH_PACKAGE_REGISTRY_FIXTURE_DIR.
This helper exposes normalized package registry facts only. It does not
make live service calls, mutate provider state, provision services, return
commands for execution, or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.package_registry.detect.v1 detect missing_fixture_detect_json ;;
  "repository explain") _json_file repository.json || _fail_json queuebash.package_registry.repository.v1 repository missing_fixture_repository_json ;;
  "package explain") _json_file package.json || _fail_json queuebash.package_registry.package.v1 package missing_fixture_package_json ;;
  "provenance explain") _json_file provenance.json || _fail_json queuebash.package_registry.provenance.v1 provenance missing_fixture_provenance_json ;;
  "policy explain") _json_file policy.json || _fail_json queuebash.package_registry.policy.v1 policy missing_fixture_policy_json ;;
  *) echo "ERROR: unsupported package registry provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
