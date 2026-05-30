#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q 'Provider family: APAC/China' docs/APAC_CHINA_EXPLAINABILITY.md
grep -q 'queuebash.apac_china.explain.v1' docs/APAC_CHINA_EXPLAINABILITY.md
grep -q 'Fail-closed' docs/APAC_CHINA_EXPLAINABILITY.md
grep -q 'access keys' docs/APAC_CHINA_EXPLAINABILITY.md
grep -q 'signed URLs' docs/APAC_CHINA_EXPLAINABILITY.md
echo 'PASS apac_china_explain_static'
