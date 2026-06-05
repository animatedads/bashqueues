#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for f in \
  docs/HYBRID_ONPREM_PROVIDER_CONTRACTS.md \
  docs/HYBRID_ONPREM_CLASS_CRITERIA.md \
  docs/HYBRID_ONPREM_EXPLAINABILITY.md \
  docs/HYBRID_ONPREM_LEGAL_COMPLIANCE.md \
  providers.d/hybrid_onprem/hybrid_onprem_provider.sh \
  policies.d/hybrid-onprem/default.env.example \
  policies.d/hybrid-onprem/regions.tsv \
  classes/CLOUD_HYBRID_DEFAULT.env \
  classes/CLOUD_HYBRID_HIGH_ASSURANCE.env \
  tests/fixtures/hybrid_onprem/vmware/detect.json; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done
grep -Eq 'QUEUEBASH_VERSION="0\.18\.(48|49|([5-9][0-9]|[1-9][0-9][0-9]))"' queuebash.sh
grep -q '0.18.46 BOB2 primary-source validation + BOB12 patchset registry merged' CHANGELOG.md || grep -q '0.18.46 - BOB2 primary-source validation + BOB12 patchset registry merged' CHANGELOG.md || grep -q '0.18.41 - BOB2 hybrid/on-prem provider contracts merged with cloud lifecycle + ask provider' CHANGELOG.md
grep -q '0.18.46 BOB2 primary-source validation + BOB12 patchset registry merged' README.md || grep -q '0.18.46 - BOB2 primary-source validation + BOB12 patchset registry merged' README.md || grep -q '0.18.41 BOB2 hybrid/on-prem provider contracts merged with cloud lifecycle + ask provider' README.md
grep -q 'queuebash.hybrid_onprem.vmware.detect.v1' docs/HYBRID_ONPREM_PROVIDER_CONTRACTS.md
grep -q 'mapped pending validation' docs/HYBRID_ONPREM_LEGAL_COMPLIANCE.md
grep -q 'signed_url_redaction' classes/CLOUD_HYBRID_HIGH_ASSURANCE.env
grep -q 'QUEUEBASH_HYBRID_ONPREM_LIVE_CHECKS=0' policies.d/hybrid-onprem/default.env.example
grep -q 'Live provider checks are intentionally not implemented' providers.d/hybrid_onprem/hybrid_onprem_provider.sh
for p in vmware openstack openshift; do
  [[ -d "tests/fixtures/hybrid_onprem/$p" ]] || exit 1
  grep -q "queuebash.hybrid_onprem.$p.detect.v1" "tests/fixtures/hybrid_onprem/$p/detect.json"
done
if grep -q '_queue_hybrid_onprem\|queue hybrid-onprem\|queue hybrid_onprem\|govc vm.power\|openstack server create\|openstack server delete\|oc apply\|kubectl apply' queuebash.sh providers.d/hybrid_onprem/hybrid_onprem_provider.sh docs/HYBRID_ONPREM_PROVIDER_CONTRACTS.md; then
  echo 'unexpected hybrid/on-prem dispatcher/live mutation hook found' >&2
  exit 1
fi
[[ ! -e assets.d/net_usage.sh ]]
[[ -e caps.d/net_usage.sh ]]
echo 'PASS hybrid_onprem_provider_contracts_static'
