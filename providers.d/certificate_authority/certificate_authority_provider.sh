#!/usr/bin/env bash
# bashqueues certificate authority provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_CERTIFICATE_AUTHORITY_FIXTURE_DIR:-}"
_live="${QUEUEBASH_CERTIFICATE_AUTHORITY_LIVE_CHECKS:-0}"

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
  "provider_family": "certificate_authority",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_CERTIFICATE_AUTHORITY_FIXTURE_DIR fixtures for contract tests. Live certificate authority reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/certificate_authority/certificate_authority_provider.sh detect
  providers.d/certificate_authority/certificate_authority_provider.sh issuer explain
  providers.d/certificate_authority/certificate_authority_provider.sh certificate explain
  providers.d/certificate_authority/certificate_authority_provider.sh policy explain
  providers.d/certificate_authority/certificate_authority_provider.sh revocation explain

Default mode is fixture-only via QUEUEBASH_CERTIFICATE_AUTHORITY_FIXTURE_DIR.
This helper exposes normalized certificate authority facts only. It does not
make live service calls, mutate provider state, provision services, return
commands for execution, or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.certificate_authority.detect.v1 detect missing_fixture_detect_json ;;
  "issuer explain") _json_file issuer.json || _fail_json queuebash.certificate_authority.issuer.v1 issuer missing_fixture_issuer_json ;;
  "certificate explain") _json_file certificate.json || _fail_json queuebash.certificate_authority.certificate.v1 certificate missing_fixture_certificate_json ;;
  "policy explain") _json_file policy.json || _fail_json queuebash.certificate_authority.policy.v1 policy missing_fixture_policy_json ;;
  "revocation explain") _json_file revocation.json || _fail_json queuebash.certificate_authority.revocation.v1 revocation missing_fixture_revocation_json ;;
  *) echo "ERROR: unsupported certificate authority provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
