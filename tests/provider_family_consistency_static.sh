#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

# Release identity for Bob2 consistency backfill.
grep -Eq 'QUEUEBASH_VERSION="0\.18\.(49|([5-9][0-9]|[1-9][0-9][0-9]))"' queuebash.sh || fail 'version not compatible with 0.18.49+'
grep -Fq '0.18.46 BOB2 primary-source validation + BOB12 patchset registry merged' README.md || fail 'README 0.18.46 entry missing'
grep -Fq '0.18.46 - BOB2 primary-source validation + BOB12 patchset registry merged' CHANGELOG.md || fail 'CHANGELOG 0.18.46 entry missing'

for f in \
  docs/PROVIDER_FAMILY_CONSISTENCY.md \
  docs/PLATFORM_PARITY_STATUS.md \
  docs/CLOUD_PLATFORM_PARITY.md \
  policies.d/cloud-resource/provider-family-consistency.json \
  tests/provider_family_consistency_json_contract_static.py; do
  [[ -f "$f" ]] || fail "missing $f"
done

grep -q 'fixture-first provider-family packs' docs/PLATFORM_PARITY_STATUS.md || fail 'status vocabulary missing'
grep -q 'first_tier_contract' docs/PROVIDER_FAMILY_CONSISTENCY.md || fail 'first_tier status missing'
grep -q 'high_standard_reference' docs/PROVIDER_FAMILY_CONSISTENCY.md || fail 'reference status missing'
grep -q 'fixture_first_provider_family' policies.d/cloud-resource/provider-family-consistency.json || fail 'fixture-family status missing'
grep -q 'queuebash.provider_family_consistency.v1' policies.d/cloud-resource/provider-family-consistency.json || fail 'schema missing'
grep -q '0.18.43 Bob2 provider-family consistency backfill' docs/CLOUD_PLATFORM_PARITY.md || fail 'cloud parity 0.18.43 note missing'

# This backfill is not a live-provider or provisioning package.
if grep -R -nE 'gcloud compute instances create|az vm create|aws ec2 run-instances|oci compute instance launch|openstack server create|kubectl apply|cf deploy|fly deploy|fastly compute publish' \
  docs/PROVIDER_FAMILY_CONSISTENCY.md docs/PLATFORM_PARITY_STATUS.md tests/provider_family_consistency_json_contract_static.py policies.d/cloud-resource/provider-family-consistency.json >/tmp/provider_family_forbidden.$$ 2>/dev/null; then
  cat /tmp/provider_family_forbidden.$$ >&2
  rm -f /tmp/provider_family_forbidden.$$
  fail 'live/provisioning command leaked into consistency backfill'
fi
rm -f /tmp/provider_family_forbidden.$$

[[ ! -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'
[[ -e caps.d/net_usage.sh ]] || fail 'caps.d/net_usage.sh must remain present'

echo 'PASS provider_family_consistency_static'
