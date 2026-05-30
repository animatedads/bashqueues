#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

for f in \
  docs/AZURE_PROVIDER_CONTRACTS.md \
  docs/AZURE_CLASS_CRITERIA.md \
  docs/AZURE_EXPLAINABILITY.md \
  docs/AZURE_LEGAL_COMPLIANCE.md \
  providers.d/azure/azure_provider.sh \
  policies.d/azure/default.env.example \
  policies.d/azure/regions.tsv \
  classes/CLOUD_AZURE_DEFAULT.env \
  classes/CLOUD_AZURE_GDPR.env \
  classes/CLOUD_AZURE_HIGH_ASSURANCE.env \
  tests/fixtures/azure/detect.json; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(33|34|35|36|37|38|39|40|41|46|47|48|49|[5-9][0-9])"' queuebash.sh
grep -q '0.18.49 - BOB12 patchset file-registry hardening' CHANGELOG.md || grep -q '0.18.48 BOB12 Bob10 handoff evidence merge repair' CHANGELOG.md || grep -q '0.18.48 - BOB12 Bob10 handoff evidence merge repair' CHANGELOG.md || grep -q '0.18.35 - APAC/China cloud provider contracts' CHANGELOG.md
grep -q '0.18.49 BOB12 patchset file-registry hardening' README.md || grep -q '0.18.48 BOB12 Bob10 handoff evidence merge repair' README.md || grep -q '0.18.48 - BOB12 Bob10 handoff evidence merge repair' README.md || grep -q '0.18.35 APAC/China cloud provider contracts' README.md
grep -q 'queuebash.azure.detect.v1' docs/AZURE_PROVIDER_CONTRACTS.md
grep -q 'queuebash.azure.identity.v1' docs/AZURE_PROVIDER_CONTRACTS.md
grep -q 'No Azure access tokens in job files' docs/AZURE_PROVIDER_CONTRACTS.md
grep -q 'mapped pending validation' docs/AZURE_LEGAL_COMPLIANCE.md
grep -q 'sas_redaction' classes/CLOUD_AZURE_GDPR.env
grep -q 'QUEUEBASH_AZURE_LIVE_CHECKS=0' policies.d/azure/default.env.example
grep -q 'Live Azure checks are intentionally not implemented' providers.d/azure/azure_provider.sh

if grep -q '_queue_azure\|queue azure\|az vm create\|az vm delete\|az group delete' queuebash.sh providers.d/azure/azure_provider.sh docs/AZURE_PROVIDER_CONTRACTS.md; then
  echo 'unexpected Azure dispatcher/live provisioning hook found' >&2
  exit 1
fi

[[ ! -e assets.d/net_usage.sh ]]
[[ -e caps.d/net_usage.sh ]]

echo 'PASS azure_provider_contracts_static'
