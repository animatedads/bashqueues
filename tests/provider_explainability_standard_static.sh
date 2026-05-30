#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(49|[5-9][0-9])"' queuebash.sh || fail 'version not compatible with 0.18.49+'
grep -Fq '0.18.46 BOB2 primary-source validation + BOB12 patchset registry merged' README.md || fail 'README 0.18.46 entry missing'
grep -Fq '0.18.46 - BOB2 primary-source validation + BOB12 patchset registry merged' CHANGELOG.md || fail 'CHANGELOG 0.18.46 entry missing'

for f in \
  docs/PROVIDER_EXPLAINABILITY_STANDARD.md \
  docs/PROVIDER_FAMILY_CONSISTENCY.md \
  docs/PLATFORM_PARITY_STATUS.md \
  policies.d/cloud-resource/provider-explainability-standard.json \
  tests/provider_explainability_standard_json_contract_static.py; do
  [[ -f "$f" ]] || fail "missing $f"
done

grep -q 'Provider-family presence is not the same as first-tier parity' docs/PROVIDER_EXPLAINABILITY_STANDARD.md || fail 'honesty wording missing'
grep -q 'mapped pending validation' docs/PROVIDER_EXPLAINABILITY_STANDARD.md || fail 'mapped validation wording missing'
grep -q 'queuebash.provider_explainability_standard.v1' policies.d/cloud-resource/provider-explainability-standard.json || fail 'policy schema missing'
grep -q 'provider explainability standard' docs/CLOUD_PLATFORM_PARITY.md || fail 'cloud parity standard note missing'

for doc in \
  docs/GCP_EXPLAINABILITY.md \
  docs/AZURE_EXPLAINABILITY.md \
  docs/EU_SOVEREIGN_EXPLAINABILITY.md \
  docs/APAC_CHINA_EXPLAINABILITY.md \
  docs/GPU_CLOUD_EXPLAINABILITY.md \
  docs/EDGE_CLOUD_EXPLAINABILITY.md \
  docs/HYBRID_ONPREM_EXPLAINABILITY.md; do
  [[ -f "$doc" ]] || fail "missing explain doc $doc"
  grep -q 'Provider:' "$doc" || fail "Provider field missing in $doc"
  grep -q 'Decision:' "$doc" || fail "Decision field missing in $doc"
  grep -q 'Fail-closed' "$doc" || fail "Fail-closed field missing in $doc"
done

# This standardization package must not add live/provisioning behaviour.
if grep -R -nE 'gcloud compute instances create|az vm create|aws ec2 run-instances|oci compute instance launch|openstack server create|kubectl apply|cf deploy|fly deploy|fastly compute publish|terraform apply' \
  docs/PROVIDER_EXPLAINABILITY_STANDARD.md policies.d/cloud-resource/provider-explainability-standard.json tests/provider_explainability_standard_json_contract_static.py >/tmp/provider_explain_forbidden.$$ 2>/dev/null; then
  cat /tmp/provider_explain_forbidden.$$ >&2
  rm -f /tmp/provider_explain_forbidden.$$
  fail 'live/provisioning command leaked into explainability backfill'
fi
rm -f /tmp/provider_explain_forbidden.$$

[[ ! -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'
[[ -e caps.d/net_usage.sh ]] || fail 'caps.d/net_usage.sh must remain present'

echo 'PASS provider_explainability_standard_static'
