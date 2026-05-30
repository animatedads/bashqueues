#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q 'GPU cloud provisioning template parity' README.md
grep -q 'GPU cloud provisioning template parity' CHANGELOG.md
grep -Eq '^QUEUEBASH_VERSION="0\.18\.[0-9]+"$' queuebash.sh
grep -q 'gpu-coreweave-a100-training' policies.d/cloud-provision/templates.example.json
grep -q 'gpu-lambda-h100-training' policies.d/cloud-provision/templates.example.json
grep -q 'gpu-dgx-export-review' policies.d/cloud-provision/templates.example.json
grep -q 'bad-gpu-cost-breach' policies.d/cloud-provision/templates.example.json
grep -q 'gpu_cloud_stack.sh' providers.d/cloud_infra/cloud_infra.sh
test -f providers.d/cloud_infra/gpu_cloud_stack.sh
test -f docs/CLOUD_PROVISIONING_GPU_TEMPLATES.md
