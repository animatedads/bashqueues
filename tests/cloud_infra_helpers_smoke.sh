#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export QUEUEBASH_CLOUD_INFRA_REGISTRY="$ROOT/tests/fixtures/cloud_infra/registry.json"
export QUEUEBASH_CLOUD_INFRA_LIVE=0

list_json="$(providers.d/cloud_infra/cloud_infra.sh list)"
plan_json="$(providers.d/cloud_infra/cloud_infra.sh plan oci-free-london start)"
start_json="$(providers.d/cloud_infra/cloud_infra.sh start oci-free-london)"
status_json="$(providers.d/cloud_infra/cloud_infra.sh status oci-free-london)"

echo "$list_json" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["schema"]=="queuebash.cloud_infra.list.v1"; assert any(s["id"]=="oci-free-london" for s in d["services"])'
echo "$plan_json" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["schema"]=="queuebash.cloud_infra.action.v1"; assert d["decision"]=="dry_run"; assert d["action"]=="plan-start"; assert d["registry_checked"] is True; assert d["mutated"] is False'
echo "$start_json" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"]=="dry_run"; assert d["provider"]=="oci"; assert d["live"] is False; assert d["legal"]["sovereignty"]=="uk"'
echo "$status_json" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"]=="dry_run"; assert d["reason"]=="live_gate_not_enabled"'

export QUEUEBASH_CLOUD_INFRA_REGISTRY="$ROOT/tests/fixtures/cloud_infra/registry_with_instance.json"
stop_json="$(providers.d/cloud_infra/cloud_infra.sh stop oci-free-london)"
echo "$stop_json" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"]=="dry_run"; assert "instance_id" in d; assert d["mutated"] is False'

if providers.d/cloud_infra/cloud_infra.sh start does-not-exist >/tmp/cloud_infra_missing.json 2>/dev/null; then
  echo 'missing service unexpectedly allowed' >&2
  exit 1
fi
/usr/bin/python3 -c 'import json; d=json.load(open("/tmp/cloud_infra_missing.json")); assert d["decision"]=="deny"; assert d["reason"]=="service_not_found"'

echo 'cloud_infra_helpers_smoke: PASS'
