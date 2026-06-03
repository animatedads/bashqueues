#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test -x providers.d/gpu_marketplace/gpu_marketplace_provider.sh
bash -n providers.d/gpu_marketplace/gpu_marketplace_provider.sh
test -f docs/GPU_MARKETPLACE_PROVIDER_CONTRACTS.md
test -f docs/GPU_MARKETPLACE_EXPLAINABILITY.md
test -f docs/GPU_MARKETPLACE_LEGAL_COMPLIANCE.md
grep -q "fixture-first" docs/GPU_MARKETPLACE_PROVIDER_CONTRACTS.md
grep -q "provider output is never shell" docs/GPU_MARKETPLACE_PROVIDER_CONTRACTS.md
grep -q "not acceptance evidence for live provider support" docs/GPU_MARKETPLACE_EXPLAINABILITY.md
grep -q "must not include secrets" docs/GPU_MARKETPLACE_LEGAL_COMPLIANCE.md
echo "PASS gpu_marketplace_provider_contracts_static"
