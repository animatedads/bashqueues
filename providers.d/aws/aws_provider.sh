#!/usr/bin/env bash
# bashqueues AWS provider contract helper.
# Fixture/read-only contract package. No provisioning or mutation.
set -euo pipefail

_fixture_dir="${QUEUEBASH_AWS_FIXTURE_DIR:-}"
_live="${QUEUEBASH_AWS_LIVE_CHECKS:-0}"

_json_file() { local name="$1"; [[ -n "$_fixture_dir" && -f "$_fixture_dir/$name" ]] && cat "$_fixture_dir/$name" && return 0; return 1; }

_fail_json() {
  local schema="$1" check="$2" reason="$3"
  /usr/bin/python3 - "$schema" "$check" "$reason" <<'PYFAIL'
import json, sys
schema, check, reason = sys.argv[1:4]
print(json.dumps({
  "schema": schema,
  "provider": "aws",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "remediation_hint": "Provide QUEUEBASH_AWS_FIXTURE_DIR fixtures for contract tests. Live AWS checks are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/aws/aws_provider.sh detect
  providers.d/aws/aws_provider.sh metadata
  providers.d/aws/aws_provider.sh identity explain
  providers.d/aws/aws_provider.sh region explain
  providers.d/aws/aws_provider.sh data-protection explain
  providers.d/aws/aws_provider.sh itar explain
  providers.d/aws/aws_provider.sh finops explain
  providers.d/aws/aws_provider.sh resource-shape explain

Default mode is fixture-only via QUEUEBASH_AWS_FIXTURE_DIR.
This contract package performs no live EC2/S3/IAM/Billing mutation and does not provision resources.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.aws.detect.v1 detect missing_fixture_detect_json ;;
  "metadata ") _json_file metadata.json || _fail_json queuebash.aws.metadata.v1 metadata missing_fixture_metadata_json ;;
  "identity explain") _json_file identity.json || _fail_json queuebash.aws.identity.v1 identity missing_fixture_identity_json ;;
  "region explain") _json_file region.json || _fail_json queuebash.aws.region.v1 region missing_fixture_region_json ;;
  "data-protection explain") _json_file data_protection.json || _fail_json queuebash.aws.data_protection.v1 data-protection missing_fixture_data_protection_json ;;
  "itar explain") _json_file itar.json || _fail_json queuebash.aws.itar.v1 itar missing_fixture_itar_json ;;
  "finops explain") _json_file finops.json || _fail_json queuebash.aws.finops.v1 finops missing_fixture_finops_json ;;
  "resource-shape explain") _json_file resource_shape.json || _fail_json queuebash.aws.resource_shape.v1 resource-shape missing_fixture_resource_shape_json ;;
  *) echo "ERROR: unsupported AWS provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
