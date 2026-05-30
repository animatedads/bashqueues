#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q 'Provider family: Hybrid/on-prem' docs/HYBRID_ONPREM_EXPLAINABILITY.md
grep -q 'queuebash.hybrid_onprem.explain.v1' docs/HYBRID_ONPREM_EXPLAINABILITY.md
grep -q 'Fail-closed' docs/HYBRID_ONPREM_EXPLAINABILITY.md
grep -q 'Kubeconfigs' docs/HYBRID_ONPREM_EXPLAINABILITY.md
grep -q 'vCenter credentials' docs/HYBRID_ONPREM_EXPLAINABILITY.md
echo 'PASS hybrid_onprem_explain_static'
