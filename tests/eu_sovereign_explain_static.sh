#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q 'Provider family: EU sovereign' docs/EU_SOVEREIGN_EXPLAINABILITY.md
grep -q 'queuebash.eu_sovereign.explain.v1' docs/EU_SOVEREIGN_EXPLAINABILITY.md
grep -q 'Fail-closed' docs/EU_SOVEREIGN_EXPLAINABILITY.md
grep -q 'access tokens' docs/EU_SOVEREIGN_EXPLAINABILITY.md
grep -q 'signed URLs' docs/EU_SOVEREIGN_EXPLAINABILITY.md
echo 'PASS eu_sovereign_explain_static'
