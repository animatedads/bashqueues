#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
PROVIDER="providers.d/cloud_provision/cloud_provision.sh"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

self="$($PROVIDER self-test --json)"
echo "$self" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"]=="allow"; assert d["reason"]=="self_test_passed"; assert d["mutated"] is False; assert len(d["provider_plans"]) == 5'

for t in aws-ec2-gdpr oci-vm-gdpr azure-vm-gdpr gcp-compute-gdpr ibm-vpc-gdpr; do
  out="$($PROVIDER plan "$t" --json)"
  echo "$out" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["schema"]=="queuebash.cloud_provision.plan.v1"; assert d["decision"] in ("allow","review"); assert d["live_mutation"] is False; assert d["mutated"] is False; assert d["resource_record_preview"]["lifecycle_state"]=="planned"'
  dry="$($PROVIDER dry-run "$t" --json)"
  echo "$dry" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"]=="dry_run"; assert d["mutated"] is False; assert d["live"] is False'
done

for t in bad-missing-region bad-missing-legal bad-itar-on-generic bad-cost-breach; do
  if $PROVIDER dry-run "$t" --json >/tmp/cloud_provision_bad.json 2>/dev/null; then
    fail "bad template unexpectedly dry-ran successfully: $t"
  fi
  /usr/bin/python3 -c 'import json; d=json.load(open("/tmp/cloud_provision_bad.json")); assert d["decision"]=="deny"; assert d["mutated"] is False'
done

echo '[PASS] cloud provision dry-run smoke checks pass'
