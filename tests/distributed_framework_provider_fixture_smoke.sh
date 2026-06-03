#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_DISTRIBUTED_FRAMEWORK_FIXTURE_DIR="$PWD/tests/fixtures/distributed_framework"
providers.d/distributed_framework/distributed_framework_provider.sh detect | python3 -m json.tool >/dev/null
providers.d/distributed_framework/distributed_framework_provider.sh runtime explain | python3 -m json.tool >/dev/null
providers.d/distributed_framework/distributed_framework_provider.sh cluster explain | python3 -m json.tool >/dev/null
providers.d/distributed_framework/distributed_framework_provider.sh data-access explain | python3 -m json.tool >/dev/null
providers.d/distributed_framework/distributed_framework_provider.sh governance explain | python3 -m json.tool >/dev/null
echo "PASS distributed_framework_provider_fixture_smoke"
