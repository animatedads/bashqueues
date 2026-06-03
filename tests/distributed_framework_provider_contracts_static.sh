#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test -x providers.d/distributed_framework/distributed_framework_provider.sh
bash -n providers.d/distributed_framework/distributed_framework_provider.sh
test -f docs/DISTRIBUTED_FRAMEWORK_PROVIDER_CONTRACTS.md
test -f docs/DISTRIBUTED_FRAMEWORK_EXPLAINABILITY.md
test -f docs/DISTRIBUTED_FRAMEWORK_LEGAL_COMPLIANCE.md
grep -q "fixture-first" docs/DISTRIBUTED_FRAMEWORK_PROVIDER_CONTRACTS.md
grep -q "provider output is never shell" docs/DISTRIBUTED_FRAMEWORK_PROVIDER_CONTRACTS.md
grep -q "not acceptance evidence for live provider support" docs/DISTRIBUTED_FRAMEWORK_EXPLAINABILITY.md
grep -q "must not include secrets" docs/DISTRIBUTED_FRAMEWORK_LEGAL_COMPLIANCE.md
echo "PASS distributed_framework_provider_contracts_static"
