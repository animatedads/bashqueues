#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

[[ -f docs/PROVIDER_PARITY_REPORT.md ]] || fail 'missing docs/PROVIDER_PARITY_REPORT.md'
[[ -x providers.d/cloud_resource/provider_parity_report.py ]] || fail 'missing executable provider parity report helper'
[[ -f policies.d/cloud-resource/provider-parity-report.json ]] || fail 'missing provider parity report policy'

grep -q 'queuebash.provider_parity_report.v1' docs/PROVIDER_PARITY_REPORT.md || fail 'report schema missing from docs'
grep -q 'queuebash.provider_parity_report_policy.v1' policies.d/cloud-resource/provider-parity-report.json || fail 'policy schema missing'
grep -q 'no live cloud API calls' docs/PROVIDER_PARITY_REPORT.md || fail 'no-live boundary missing'
grep -q 'no queue dispatch refactor' docs/PROVIDER_PARITY_REPORT.md || fail 'no-dispatch boundary missing'

if grep -R 'aws ec2 run-instances\|az vm create\|gcloud compute instances create\|oci compute instance launch' \
  providers.d/cloud_resource/provider_parity_report.py docs/PROVIDER_PARITY_REPORT.md policies.d/cloud-resource/provider-parity-report.json; then
  fail 'provider parity report must not contain live provisioning commands'
fi

python3 -m py_compile providers.d/cloud_resource/provider_parity_report.py

echo 'PASS provider_parity_report_static'
