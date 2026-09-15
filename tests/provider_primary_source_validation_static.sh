#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(49|[5-9][0-9])"' queuebash.sh || fail 'version not compatible with 0.18.49+'
grep -Fq '0.18.46 BOB2 primary-source validation + BOB12 patchset registry merged' README.md || fail 'README 0.18.46 entry missing'
grep -Fq '0.18.46 - BOB2 primary-source validation + BOB12 patchset registry merged' CHANGELOG.md || fail 'CHANGELOG 0.18.46 entry missing'

for f in \
  docs/PROVIDER_PRIMARY_SOURCE_VALIDATION.md \
  docs/PROVIDER_FAMILY_CONSISTENCY.md \
  docs/PLATFORM_PARITY_STATUS.md \
  docs/CLOUD_PLATFORM_PARITY.md \
  policies.d/cloud-resource/provider-primary-source-validation.json \
  tests/provider_primary_source_validation_json_contract_static.py; do
  [[ -f "$f" ]] || fail "missing $f"
done

grep -q 'queuebash.provider_primary_source_validation.v1' policies.d/cloud-resource/provider-primary-source-validation.json || fail 'validation policy schema missing'
grep -q 'mapped_pending_validation' docs/PROVIDER_PRIMARY_SOURCE_VALIDATION.md || fail 'mapped pending status missing'
grep -q 'primary_source_validated' docs/PROVIDER_PRIMARY_SOURCE_VALIDATION.md || fail 'primary-source status missing'
grep -q 'accepted_project_criterion' docs/PROVIDER_PRIMARY_SOURCE_VALIDATION.md || fail 'accepted criterion status missing'
grep -q 'Region-table warnings' docs/PROVIDER_PRIMARY_SOURCE_VALIDATION.md || fail 'region warning section missing'
grep -q 'Export-control and ITAR normalisation' docs/PROVIDER_PRIMARY_SOURCE_VALIDATION.md || fail 'export-control section missing'
grep -q 'External AI' docs/PROVIDER_PRIMARY_SOURCE_VALIDATION.md || fail 'external AI warning missing'
grep -q 'not legal certifications' docs/PLATFORM_PARITY_STATUS.md || fail 'platform parity legal warning missing'
grep -q 'primary-source validation' docs/CLOUD_PLATFORM_PARITY.md || fail 'cloud parity validation note missing'

# Ensure the framework does not add live/provisioning commands or dispatcher hooks.
if grep -R -nE 'gcloud compute instances create|az vm create|aws ec2 run-instances|oci compute instance launch|openstack server create|kubectl apply|cf deploy|fly deploy|fastly compute publish|terraform apply|_queue_provider_validation|queue provider validate' \
  docs/PROVIDER_PRIMARY_SOURCE_VALIDATION.md policies.d/cloud-resource/provider-primary-source-validation.json tests/provider_primary_source_validation_json_contract_static.py >/tmp/provider_validation_forbidden.$$ 2>/dev/null; then
  cat /tmp/provider_validation_forbidden.$$ >&2
  rm -f /tmp/provider_validation_forbidden.$$
  fail 'live/provisioning/dispatcher hook leaked into primary-source validation framework'
fi
rm -f /tmp/provider_validation_forbidden.$$

[[ ! -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'
[[ -e caps.d/net_usage.sh ]] || fail 'caps.d/net_usage.sh must remain present'

echo 'PASS provider_primary_source_validation_static'
