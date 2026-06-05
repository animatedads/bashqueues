#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for f in \
  docs/EU_SOVEREIGN_PROVIDER_CONTRACTS.md \
  docs/EU_SOVEREIGN_CLASS_CRITERIA.md \
  docs/EU_SOVEREIGN_EXPLAINABILITY.md \
  docs/EU_SOVEREIGN_LEGAL_COMPLIANCE.md \
  providers.d/eu_sovereign/eu_sovereign_provider.sh \
  policies.d/eu-sovereign/default.env.example \
  policies.d/eu-sovereign/regions.tsv \
  classes/CLOUD_EU_SOVEREIGN_DEFAULT.env \
  classes/CLOUD_EU_SOVEREIGN_GDPR.env \
  classes/CLOUD_EU_SOVEREIGN_HIGH_ASSURANCE.env \
  tests/fixtures/eu_sovereign/ovhcloud/detect.json; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(34|35|36|37|38|39|4[0-9]|([5-9][0-9]|[1-9][0-9][0-9]))"' queuebash.sh
grep -q '0.18.46 BOB2 primary-source validation + BOB12 patchset registry merged' CHANGELOG.md || grep -q '0.18.46 - BOB2 primary-source validation + BOB12 patchset registry merged' CHANGELOG.md || grep -q '0.18.35 - APAC/China cloud provider contracts' CHANGELOG.md
grep -q '0.18.46 BOB2 primary-source validation + BOB12 patchset registry merged' README.md || grep -q '0.18.46 - BOB2 primary-source validation + BOB12 patchset registry merged' README.md || grep -q '0.18.35 APAC/China cloud provider contracts' README.md
grep -q 'queuebash.eu_sovereign.ovhcloud.detect.v1' docs/EU_SOVEREIGN_PROVIDER_CONTRACTS.md
grep -q 'mapped pending validation' docs/EU_SOVEREIGN_LEGAL_COMPLIANCE.md
grep -q 'signed_url_redaction' classes/CLOUD_EU_SOVEREIGN_GDPR.env
grep -q 'QUEUEBASH_EU_SOVEREIGN_LIVE_CHECKS=0' policies.d/eu-sovereign/default.env.example
grep -q 'Live provider checks are intentionally not implemented' providers.d/eu_sovereign/eu_sovereign_provider.sh
for p in ovhcloud scaleway hetzner otc; do
  [[ -d "tests/fixtures/eu_sovereign/$p" ]] || exit 1
  grep -q "queuebash.eu_sovereign.$p.detect.v1" "tests/fixtures/eu_sovereign/$p/detect.json"
done
if grep -q '_queue_eu_sovereign\|queue eu-sovereign\|queue eu_sovereign\|hcloud server create\|scw instance server create\|ovh.*create\|openstack server create' queuebash.sh providers.d/eu_sovereign/eu_sovereign_provider.sh docs/EU_SOVEREIGN_PROVIDER_CONTRACTS.md; then
  echo 'unexpected EU sovereign dispatcher/live provisioning hook found' >&2
  exit 1
fi
[[ ! -e assets.d/net_usage.sh ]]
[[ -e caps.d/net_usage.sh ]]
echo 'PASS eu_sovereign_provider_contracts_static'
