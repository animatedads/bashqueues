#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q 'Provider: Azure' docs/AZURE_EXPLAINABILITY.md
grep -q 'queuebash.azure.explain.v1' docs/AZURE_EXPLAINABILITY.md
grep -q 'Fail-closed' docs/AZURE_EXPLAINABILITY.md
grep -q 'service principal secrets' docs/AZURE_EXPLAINABILITY.md
grep -q 'SAS tokens' docs/AZURE_EXPLAINABILITY.md

echo 'PASS azure_explain_static'
