#!/usr/bin/env bash
# bashqueues compliance evidence provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_COMPLIANCE_EVIDENCE_FIXTURE_DIR:-}"
_live="${QUEUEBASH_COMPLIANCE_EVIDENCE_LIVE_CHECKS:-0}"

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
  "provider_family": "compliance_evidence",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_COMPLIANCE_EVIDENCE_FIXTURE_DIR fixtures for contract tests. Live reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/compliance_evidence/compliance_evidence_provider.sh detect
  providers.d/compliance_evidence/compliance_evidence_provider.sh control explain
  providers.d/compliance_evidence/compliance_evidence_provider.sh evidence_pack explain
  providers.d/compliance_evidence/compliance_evidence_provider.sh attestation explain
  providers.d/compliance_evidence/compliance_evidence_provider.sh retention explain

Default mode is fixture-only via QUEUEBASH_COMPLIANCE_EVIDENCE_FIXTURE_DIR.
This helper exposes normalized compliance evidence facts only. It does not make live
service calls, mutate provider state, provision services, return executable commands,
or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.compliance_evidence.detect.v1 detect missing_fixture_detect_json ;;
  "control explain") _json_file control.json || _fail_json queuebash.compliance_evidence.control.v1 control missing_fixture_control_json ;;
  "evidence_pack explain") _json_file evidence_pack.json || _fail_json queuebash.compliance_evidence.evidence_pack.v1 evidence_pack missing_fixture_evidence_pack_json ;;
  "attestation explain") _json_file attestation.json || _fail_json queuebash.compliance_evidence.attestation.v1 attestation missing_fixture_attestation_json ;;
  "retention explain") _json_file retention.json || _fail_json queuebash.compliance_evidence.retention.v1 retention missing_fixture_retention_json ;;
  *) echo "ERROR: unsupported compliance evidence provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
