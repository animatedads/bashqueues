#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q 'Provider family: GPU cloud' docs/GPU_CLOUD_EXPLAINABILITY.md
grep -q 'queuebash.gpu_cloud.explain.v1' docs/GPU_CLOUD_EXPLAINABILITY.md
grep -q 'Fail-closed' docs/GPU_CLOUD_EXPLAINABILITY.md
grep -q 'service-account private keys\|API keys\|kubeconfigs' docs/GPU_CLOUD_EXPLAINABILITY.md
grep -q 'signed URLs' docs/GPU_CLOUD_EXPLAINABILITY.md
echo 'PASS gpu_cloud_explain_static'
