#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q 'Provider family: edge_cloud' docs/EDGE_CLOUD_EXPLAINABILITY.md
grep -q 'queuebash.edge_cloud.explain.v1' docs/EDGE_CLOUD_EXPLAINABILITY.md
grep -q 'Fail-closed' docs/EDGE_CLOUD_EXPLAINABILITY.md
grep -q 'API tokens' docs/EDGE_CLOUD_EXPLAINABILITY.md
grep -q 'signed URLs' docs/EDGE_CLOUD_EXPLAINABILITY.md
echo 'PASS edge_cloud_explain_static'
