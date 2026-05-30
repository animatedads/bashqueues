#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

for f in \
  docs/GCP_PROVIDER_CONTRACTS.md \
  docs/GCP_CLASS_CRITERIA.md \
  docs/GCP_EXPLAINABILITY.md \
  docs/GCP_LEGAL_COMPLIANCE.md \
  providers.d/gcp/gcp_provider.sh \
  policies.d/gcp/default.env.example \
  policies.d/gcp/regions.tsv \
  classes/CLOUD_GCP_DEFAULT.env \
  classes/CLOUD_GCP_GDPR.env \
  classes/CLOUD_GCP_HIGH_ASSURANCE.env \
  tests/fixtures/gcp/detect.json; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done

grep -q 'queuebash.gcp.detect.v1' docs/GCP_PROVIDER_CONTRACTS.md
grep -q 'queuebash.gcp.identity.v1' docs/GCP_PROVIDER_CONTRACTS.md
grep -q 'No service-account private keys in job files' docs/GCP_PROVIDER_CONTRACTS.md
grep -q 'pending validation' docs/GCP_LEGAL_COMPLIANCE.md
grep -q 'signed_url_redaction' classes/CLOUD_GCP_GDPR.env
grep -q 'QUEUEBASH_GCP_LIVE_CHECKS=0' policies.d/gcp/default.env.example
grep -q 'Live GCP checks are intentionally not implemented' providers.d/gcp/gcp_provider.sh

if grep -q '_queue_gcp\|queue gcp\|gcloud compute instances create\|gcloud compute instances delete' queuebash.sh providers.d/gcp/gcp_provider.sh docs/GCP_PROVIDER_CONTRACTS.md; then
  echo 'unexpected GCP dispatcher/live provisioning hook found' >&2
  exit 1
fi

[[ ! -e assets.d/net_usage.sh ]]
[[ -e caps.d/net_usage.sh ]]

echo 'PASS gcp_provider_contracts_static'
