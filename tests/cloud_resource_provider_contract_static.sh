#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(30|31|32|33|34|35|36|37|38|39|40|41|47|48|49|[5-9][0-9])"' queuebash.sh || fail 'version not bumped to 0.18.30 or newer'
grep -q '0.18.35 - APAC/China cloud provider contracts' CHANGELOG.md || fail 'changelog entry missing'
grep -q '0.18.35 APAC/China cloud provider contracts' README.md || fail 'README entry missing'

for f in \
  docs/CLOUD_RESOURCE_PROVIDER.md \
  docs/CLOUD_PLATFORM_PARITY.md \
  docs/CLOUD_INFRASTRUCTURE_HELPERS.md \
  providers.d/cloud_resource/cloud_resource_provider.sh \
  providers.d/cloud_infra/cloud_infra.sh \
  assets.d/cloud_resource.sh \
  policies.d/cloud-resource/platform-parity.json \
  examples/providers/cloud-resource-file.env.example \
  examples/cloud-resource/oci-vm-gdpr.example.json \
  classes/CLOUD_RESOURCE_GDPR.env; do
  [[ -f "$f" ]] || fail "missing $f"
done

bash -n providers.d/cloud_resource/cloud_resource_provider.sh || fail 'provider bash -n failed'
bash -n assets.d/cloud_resource.sh || fail 'asset bash -n failed'
bash -n classes/CLOUD_RESOURCE_GDPR.env || fail 'class bash -n failed'

for f in providers.d/cloud_infra/*.sh; do
  bash -n "$f" || fail "cloud infra helper bash -n failed: $f"
done

grep -q 'queuebash.cloud_resource.v1' docs/CLOUD_RESOURCE_PROVIDER.md || fail 'resource schema missing'
grep -q 'queuebash.cloud_resource_claim.v1' docs/CLOUD_RESOURCE_PROVIDER.md || fail 'claim schema missing'
grep -q 'queuebash.cloud_resource_decision.v1' docs/CLOUD_RESOURCE_PROVIDER.md || fail 'decision schema missing'
grep -q 'Do not claim equal functionality' docs/CLOUD_PLATFORM_PARITY.md || fail 'parity warning missing'
grep -q 'platform coverage is not equal yet' docs/CLOUD_PLATFORM_PARITY.md || fail 'not-equal verdict missing'
grep -q 'cloud_resource:available' assets.d/cloud_resource.sh || fail 'cloud_resource available facility missing'
grep -q 'queue_asset_check_cloud_resource_available' assets.d/cloud_resource.sh || fail 'cloud_resource available check missing'
grep -q 'QUEUEBASH_CLOUD_RESOURCE_STORE_SECRETS=0' examples/providers/cloud-resource-file.env.example || fail 'secret storage guard missing'

if grep -R 'QUEUEBASH_CLOUD_INFRA_LIVE=1' providers.d/cloud_resource assets.d/cloud_resource.sh docs/CLOUD_RESOURCE_PROVIDER.md >/dev/null 2>&1; then
  fail 'cloud resource provider must not require live infra mutation'
fi
if grep -R 'oci compute instance launch\|aws ec2 run-instances\|az vm create\|gcloud compute instances create' providers.d/cloud_resource assets.d/cloud_resource.sh >/dev/null 2>&1; then
  fail 'cloud resource provider contains live provisioning command'
fi
[[ ! -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'
[[ -f caps.d/net_usage.sh ]] || fail 'caps.d/net_usage.sh may remain present and is expected'

echo '[PASS] cloud resource provider contract static checks pass'
