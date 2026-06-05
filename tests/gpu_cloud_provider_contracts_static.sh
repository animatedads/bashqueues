#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for f in \
  docs/GPU_CLOUD_PROVIDER_CONTRACTS.md \
  docs/GPU_CLOUD_CLASS_CRITERIA.md \
  docs/GPU_CLOUD_EXPLAINABILITY.md \
  docs/GPU_CLOUD_LEGAL_COMPLIANCE.md \
  providers.d/gpu_cloud/gpu_cloud_provider.sh \
  policies.d/gpu-cloud/default.env.example \
  policies.d/gpu-cloud/regions.tsv \
  classes/CLOUD_GPU_DEFAULT.env \
  classes/CLOUD_GPU_HIGH_ASSURANCE.env \
  classes/CLOUD_GPU_MODEL_TRAINING.env \
  tests/fixtures/gpu_cloud/coreweave/detect.json; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(36|37|38|39|4[0-9]|([5-9][0-9]|[1-9][0-9][0-9]))"' queuebash.sh
grep -q '0.18.36 - GPU cloud provider contracts' CHANGELOG.md
grep -q '0.18.36 GPU cloud provider contracts' README.md
grep -q 'queuebash.gpu_cloud.coreweave.detect.v1' docs/GPU_CLOUD_PROVIDER_CONTRACTS.md
grep -q 'mapped pending validation' docs/GPU_CLOUD_LEGAL_COMPLIANCE.md
grep -q 'signed_url_redaction' classes/CLOUD_GPU_HIGH_ASSURANCE.env
grep -q 'QUEUEBASH_GPU_CLOUD_LIVE_CHECKS=0' policies.d/gpu-cloud/default.env.example
grep -q 'Live provider checks are intentionally not implemented' providers.d/gpu_cloud/gpu_cloud_provider.sh
for p in coreweave lambda dgx; do
  [[ -d "tests/fixtures/gpu_cloud/$p" ]] || exit 1
  grep -q "queuebash.gpu_cloud.$p.detect.v1" "tests/fixtures/gpu_cloud/$p/detect.json"
done
if grep -q '_queue_gpu_cloud\|queue gpu-cloud\|queue gpu_cloud\|kubectl apply\|helm install\|create cluster\|provision gpu\|instances create' queuebash.sh providers.d/gpu_cloud/gpu_cloud_provider.sh docs/GPU_CLOUD_PROVIDER_CONTRACTS.md; then
  echo 'unexpected GPU cloud dispatcher/live provisioning hook found' >&2
  exit 1
fi
[[ ! -e assets.d/net_usage.sh ]]
[[ -e caps.d/net_usage.sh ]]
echo 'PASS gpu_cloud_provider_contracts_static'
