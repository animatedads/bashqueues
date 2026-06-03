#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_GPU_MARKETPLACE_FIXTURE_DIR="$PWD/tests/fixtures/gpu_marketplace"
providers.d/gpu_marketplace/gpu_marketplace_provider.sh detect | python3 -m json.tool >/dev/null
providers.d/gpu_marketplace/gpu_marketplace_provider.sh offer explain | python3 -m json.tool >/dev/null
providers.d/gpu_marketplace/gpu_marketplace_provider.sh capability explain | python3 -m json.tool >/dev/null
providers.d/gpu_marketplace/gpu_marketplace_provider.sh quota explain | python3 -m json.tool >/dev/null
providers.d/gpu_marketplace/gpu_marketplace_provider.sh compliance explain | python3 -m json.tool >/dev/null
echo "PASS gpu_marketplace_provider_fixture_smoke"
