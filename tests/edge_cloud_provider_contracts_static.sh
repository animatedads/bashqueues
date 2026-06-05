#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for f in \
  docs/EDGE_CLOUD_PROVIDER_CONTRACTS.md \
  docs/EDGE_CLOUD_CLASS_CRITERIA.md \
  docs/EDGE_CLOUD_EXPLAINABILITY.md \
  docs/EDGE_CLOUD_LEGAL_COMPLIANCE.md \
  providers.d/edge_cloud/edge_cloud_provider.sh \
  policies.d/edge-cloud/default.env.example \
  policies.d/edge-cloud/regions.tsv \
  classes/CLOUD_EDGE_DEFAULT.env \
  classes/CLOUD_EDGE_HIGH_ASSURANCE.env \
  tests/fixtures/edge_cloud/cloudflare/detect.json; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done
grep -q 'QUEUEBASH_VERSION="' queuebash.sh
grep -q '0.18.46 BOB2 primary-source validation + BOB12 patchset registry merged' CHANGELOG.md || grep -q '0.18.46 - BOB2 primary-source validation + BOB12 patchset registry merged' CHANGELOG.md || grep -q '0.18.37 - edge cloud provider contracts' CHANGELOG.md
grep -q '0.18.46 BOB2 primary-source validation + BOB12 patchset registry merged' README.md || grep -q '0.18.46 - BOB2 primary-source validation + BOB12 patchset registry merged' README.md || grep -q '0.18.37 edge cloud provider contracts' README.md
grep -q 'queuebash.edge_cloud.cloudflare.detect.v1' docs/EDGE_CLOUD_PROVIDER_CONTRACTS.md
grep -q 'mapped pending validation' docs/EDGE_CLOUD_LEGAL_COMPLIANCE.md
grep -q 'signed_url_redaction' classes/CLOUD_EDGE_HIGH_ASSURANCE.env
grep -q 'QUEUEBASH_EDGE_CLOUD_LIVE_CHECKS=0' policies.d/edge-cloud/default.env.example
grep -q 'Live provider checks are intentionally not implemented' providers.d/edge_cloud/edge_cloud_provider.sh
for p in cloudflare fastly flyio; do
  [[ -d "tests/fixtures/edge_cloud/$p" ]] || exit 1
  grep -q "queuebash.edge_cloud.$p.detect.v1" "tests/fixtures/edge_cloud/$p/detect.json"
done
if grep -q '_queue_edge_cloud\|queue edge-cloud\|queue edge_cloud\|wrangler deploy\|fastly compute deploy\|fly deploy\|wrangler deploy' queuebash.sh providers.d/edge_cloud/edge_cloud_provider.sh docs/EDGE_CLOUD_PROVIDER_CONTRACTS.md; then
  echo 'unexpected edge cloud dispatcher/live deployment hook found' >&2
  exit 1
fi
[[ ! -e assets.d/net_usage.sh ]]
[[ -e caps.d/net_usage.sh ]]
echo 'PASS edge_cloud_provider_contracts_static'

# three-digit 0.18 minor compatibility guard: [1-9][0-9][0-9]
