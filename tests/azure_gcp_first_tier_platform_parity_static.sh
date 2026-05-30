#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.18\.[0-9]+"' queuebash.sh || fail 'version shape missing'
version=$(grep -E '^QUEUEBASH_VERSION=' queuebash.sh | head -1 | sed -E 's/.*0\.18\.([0-9]+).*/\1/')
[[ ${version:-0} -ge 52 ]] || fail 'version must be 0.18.52+'
grep -Fq '0.18.52 BOB10 Azure and GCP first-tier platform parity' README.md || fail 'README top entry missing'
grep -Fq '0.18.52 - BOB10 Azure and GCP first-tier platform parity' CHANGELOG.md || fail 'CHANGELOG top entry missing'

for f in \
  docs/CLOUD_PLATFORM_PARITY_AZURE_GCP_FIRST_TIER.md \
  policies.d/azure/cost-policy.example.json \
  policies.d/azure/export-control.example.json \
  policies.d/gcp/cost-policy.example.json \
  policies.d/gcp/export-control.example.json \
  classes/CLOUD_AZURE_ITAR.env \
  classes/CLOUD_GCP_ITAR.env \
  tests/azure_gcp_first_tier_platform_parity_json_contract_static.py; do
  [[ -f "$f" ]] || fail "missing $f"
done

grep -Fq 'first-tier contract coverage' docs/CLOUD_PLATFORM_PARITY_AZURE_GCP_FIRST_TIER.md || fail 'first-tier doc wording missing'
grep -Fq 'not a legal certification' docs/CLOUD_PLATFORM_PARITY_AZURE_GCP_FIRST_TIER.md || fail 'certification warning missing'
grep -Fq 'ITAR' policies.d/azure/export-control.example.json || fail 'Azure export-control ITAR missing'
grep -Fq 'ITAR' policies.d/gcp/export-control.example.json || fail 'GCP export-control ITAR missing'
grep -Fq 'daily_ceiling' policies.d/azure/cost-policy.example.json || fail 'Azure cost rail missing'
grep -Fq 'daily_ceiling' policies.d/gcp/cost-policy.example.json || fail 'GCP cost rail missing'

# This is parity-contract work, not live cloud or provisioning work.
if grep -R -nE 'az vm create|az deployment group create|gcloud compute instances create|gcloud deployment-manager deployments create|terraform apply|kubectl apply' \
  docs/CLOUD_PLATFORM_PARITY_AZURE_GCP_FIRST_TIER.md \
  policies.d/azure policies.d/gcp \
  tests/azure_gcp_first_tier_platform_parity_json_contract_static.py >/tmp/az_gcp_forbidden.$$ 2>/dev/null; then
  cat /tmp/az_gcp_forbidden.$$ >&2
  rm -f /tmp/az_gcp_forbidden.$$
  fail 'live/provisioning command leaked into Azure/GCP first-tier parity package'
fi
rm -f /tmp/az_gcp_forbidden.$$

echo 'PASS azure_gcp_first_tier_platform_parity_static'
