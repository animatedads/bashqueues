#!/usr/bin/env bash
# bashqueues access review provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_ACCESS_REVIEW_FIXTURE_DIR:-}"
_live="${QUEUEBASH_ACCESS_REVIEW_LIVE_CHECKS:-0}"

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
  "provider_family": "access_review",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_ACCESS_REVIEW_FIXTURE_DIR fixtures for contract tests. Live reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/access_review/access_review_provider.sh detect
  providers.d/access_review/access_review_provider.sh scope explain
  providers.d/access_review/access_review_provider.sh entitlement explain
  providers.d/access_review/access_review_provider.sh reviewer explain
  providers.d/access_review/access_review_provider.sh exception explain

Default mode is fixture-only via QUEUEBASH_ACCESS_REVIEW_FIXTURE_DIR.
This helper exposes normalized access review facts only. It does not make live
service calls, mutate provider state, provision services, return executable commands,
or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.access_review.detect.v1 detect missing_fixture_detect_json ;;
  "scope explain") _json_file scope.json || _fail_json queuebash.access_review.scope.v1 scope missing_fixture_scope_json ;;
  "entitlement explain") _json_file entitlement.json || _fail_json queuebash.access_review.entitlement.v1 entitlement missing_fixture_entitlement_json ;;
  "reviewer explain") _json_file reviewer.json || _fail_json queuebash.access_review.reviewer.v1 reviewer missing_fixture_reviewer_json ;;
  "exception explain") _json_file exception.json || _fail_json queuebash.access_review.exception.v1 exception missing_fixture_exception_json ;;
  *) echo "ERROR: unsupported access review provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
