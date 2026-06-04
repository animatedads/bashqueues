#!/usr/bin/env bash
# bashqueues identity provider provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_IDENTITY_PROVIDER_FIXTURE_DIR:-}"
_live="${QUEUEBASH_IDENTITY_PROVIDER_LIVE_CHECKS:-0}"

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
  "provider_family": "identity_provider",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_IDENTITY_PROVIDER_FIXTURE_DIR fixtures for contract tests. Live reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/identity_provider/identity_provider_provider.sh detect
  providers.d/identity_provider/identity_provider_provider.sh directory explain
  providers.d/identity_provider/identity_provider_provider.sh authentication explain
  providers.d/identity_provider/identity_provider_provider.sh federation explain
  providers.d/identity_provider/identity_provider_provider.sh group explain

Default mode is fixture-only via QUEUEBASH_IDENTITY_PROVIDER_FIXTURE_DIR.
This helper exposes normalized identity provider facts only. It does not make live
service calls, mutate provider state, provision services, return executable commands,
or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.identity_provider.detect.v1 detect missing_fixture_detect_json ;;
  "directory explain") _json_file directory.json || _fail_json queuebash.identity_provider.directory.v1 directory missing_fixture_directory_json ;;
  "authentication explain") _json_file authentication.json || _fail_json queuebash.identity_provider.authentication.v1 authentication missing_fixture_authentication_json ;;
  "federation explain") _json_file federation.json || _fail_json queuebash.identity_provider.federation.v1 federation missing_fixture_federation_json ;;
  "group explain") _json_file group.json || _fail_json queuebash.identity_provider.group.v1 group missing_fixture_group_json ;;
  *) echo "ERROR: unsupported identity provider provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
