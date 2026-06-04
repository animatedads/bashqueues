#!/usr/bin/env bash
# bashqueues metadata catalog provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_METADATA_CATALOG_FIXTURE_DIR:-}"
_live="${QUEUEBASH_METADATA_CATALOG_LIVE_CHECKS:-0}"

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
  "provider_family": "metadata_catalog",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_METADATA_CATALOG_FIXTURE_DIR fixtures for contract tests. Live catalog reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/metadata_catalog/metadata_catalog_provider.sh detect
  providers.d/metadata_catalog/metadata_catalog_provider.sh catalog explain
  providers.d/metadata_catalog/metadata_catalog_provider.sh asset explain
  providers.d/metadata_catalog/metadata_catalog_provider.sh lineage explain
  providers.d/metadata_catalog/metadata_catalog_provider.sh classification explain

Default mode is fixture-only via QUEUEBASH_METADATA_CATALOG_FIXTURE_DIR.
This helper exposes normalized metadata catalog facts only. It does not make live
service calls, mutate metadata/artifacts, provision services, return shell
commands, or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.metadata_catalog.detect.v1 detect missing_fixture_detect_json ;;
  "catalog explain") _json_file catalog.json || _fail_json queuebash.metadata_catalog.catalog.v1 catalog missing_fixture_catalog_json ;;
  "asset explain") _json_file asset.json || _fail_json queuebash.metadata_catalog.asset.v1 asset missing_fixture_asset_json ;;
  "lineage explain") _json_file lineage.json || _fail_json queuebash.metadata_catalog.lineage.v1 lineage missing_fixture_lineage_json ;;
  "classification explain") _json_file classification.json || _fail_json queuebash.metadata_catalog.classification.v1 classification missing_fixture_classification_json ;;
  *) echo "ERROR: unsupported metadata catalog provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
