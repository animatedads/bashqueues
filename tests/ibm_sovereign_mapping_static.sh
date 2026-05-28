#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL $*" >&2; exit 1; }

[[ -f docs/IBM_CLOUD_GOVERNANCE.md ]] || fail 'missing IBM governance doc'
[[ -f policies.d/sovereign/ibm.env.example ]] || fail 'missing IBM sovereign policy example'

for region in us-south us-east br-sao ca-tor eu-de eu-gb eu-es au-syd jp-osa jp-tok; do
  grep -R "${region}" assets.d/ibm_identity.sh docs/IBM_CLOUD_GOVERNANCE.md policies.d/sovereign/ibm.env.example >/dev/null || fail "missing IBM region mapping: $region"
done

grep -q 'QUEUEBASH_IBM_GDPR_REGIONS="eu-de,eu-gb,eu-es"' policies.d/sovereign/ibm.env.example || fail 'bad GDPR region example'
grep -q 'IBM Cloud identity and sovereignty' docs/IBM_CLOUD_GOVERNANCE.md || fail 'doc title missing'
grep -q 'Not included yet' docs/IBM_CLOUD_GOVERNANCE.md || fail 'doc must state excluded future integrations'
grep -q 'IBM Watson advisory provider' docs/IBM_CLOUD_GOVERNANCE.md || fail 'doc must keep Watson out of 0.18.12'
grep -q 'IBM HPCS key provider' docs/IBM_CLOUD_GOVERNANCE.md || fail 'doc must keep HPCS provider out of 0.18.12'

echo "PASS tests/ibm_sovereign_mapping_static.sh"
