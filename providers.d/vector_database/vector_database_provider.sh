#!/usr/bin/env bash
# bashqueues vector database provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_VECTOR_DATABASE_FIXTURE_DIR:-}"
_live="${QUEUEBASH_VECTOR_DATABASE_LIVE_CHECKS:-0}"

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
  "provider_family": "vector_database",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "remediation_hint": "Provide QUEUEBASH_VECTOR_DATABASE_FIXTURE_DIR fixtures for contract tests. Live reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/vector_database/vector_database_provider.sh detect 
  providers.d/vector_database/vector_database_provider.sh collection explain
  providers.d/vector_database/vector_database_provider.sh index explain
  providers.d/vector_database/vector_database_provider.sh embedding-policy explain
  providers.d/vector_database/vector_database_provider.sh retention explain

Default mode is fixture-only via QUEUEBASH_VECTOR_DATABASE_FIXTURE_DIR.
This helper exposes normalized vector database facts only. It does not make live
service calls, create resources, mutate data, return shell commands, or alter
queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.vector_database.detect.v1 detect missing_fixture_detect_json ;;
  "collection explain") _json_file collection.json || _fail_json queuebash.vector_database.collection.v1 collection missing_fixture_collection_json ;;
  "index explain") _json_file index.json || _fail_json queuebash.vector_database.index.v1 index missing_fixture_index_json ;;
  "embedding-policy explain") _json_file embedding-policy.json || _fail_json queuebash.vector_database.embedding_policy.v1 embedding_policy missing_fixture_embedding_policy_json ;;
  "retention explain") _json_file retention.json || _fail_json queuebash.vector_database.retention.v1 retention missing_fixture_retention_json ;;
  *) echo "ERROR: unsupported vector database provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
