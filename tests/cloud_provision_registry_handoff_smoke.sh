#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
PROVIDER="providers.d/cloud_provision/cloud_provision.sh"
REG="${TMPDIR:-/tmp}/queuebash-cloud-provision-handoff-$$"
trap 'rm -rf "$REG"' EXIT

out="$($PROVIDER handoff-explain aws-ec2-gdpr --json)"
echo "$out" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["schema"]=="queuebash.cloud_provision.handoff_explain.v1"; assert d["decision"]=="allow"; assert d["registry_write"] is False; assert d["mutated"] is False'

out="$($PROVIDER registry-handoff aws-ec2-gdpr --registry "$REG" --json)"
echo "$out" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["schema"]=="queuebash.cloud_provision.registry_handoff.v1"; assert d["decision"]=="allow"; assert d["registry_write"] is True; assert d["mutated"] is False; assert d["live"] is False; assert d["cloud_mutation"] is False; r=d["resource_record"]; assert r["registry_handoff_state"]=="planned"; assert r["lifecycle_state"]=="planned"; assert r["status"]=="planned"; assert r["claimable"] is False'

/usr/bin/python3 - "$REG/resources.json" <<'PY'
import json,sys
items=json.load(open(sys.argv[1]))
assert len(items)==1
r=items[0]
assert r['schema']=='queuebash.cloud_resource.v1'
assert r['provider']=='aws'
assert r['registry_handoff_state']=='planned'
assert r['lifecycle_state']=='planned'
assert r['status']=='planned'
assert r.get('claimable') is False
assert 'not-claimable' in r.get('labels', [])
PY

if providers.d/cloud_resource/cloud_resource_provider.sh claim-matching --qid TEST-QID --provider aws --type vm --region eu-west-2 --class CLOUD_AWS_GDPR --registry "$REG" --json >/tmp/qb-handoff-claim.json 2>/dev/null; then
  echo 'planned handoff unexpectedly claimable' >&2
  exit 1
fi
/usr/bin/python3 -c 'import json; d=json.load(open("/tmp/qb-handoff-claim.json")); assert d["decision"]=="deny"; assert d["reason"]=="no_matching_resource_available"'
rm -f /tmp/qb-handoff-claim.json

out="$($PROVIDER registry-handoff aws-ec2-gdpr --state claimable --registry "$REG" --json)"
echo "$out" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); r=d["resource_record"]; assert d["decision"]=="allow"; assert r["registry_handoff_state"]=="claimable"; assert r["lifecycle_state"]=="ready"; assert r["status"]=="available"; assert r["claimable"] is True'

claim="$(providers.d/cloud_resource/cloud_resource_provider.sh claim-matching --qid TEST-QID-2 --provider aws --type vm --region eu-west-2 --class CLOUD_AWS_GDPR --registry "$REG" --json)"
echo "$claim" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"]=="allow"; assert d["claim"]["resource_id"].startswith("planned-aws-ec2-gdpr-")'

echo 'PASS cloud_provision_registry_handoff_smoke'
