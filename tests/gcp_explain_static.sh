#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q 'Provider: GCP' docs/GCP_EXPLAINABILITY.md
grep -q 'queuebash.gcp.explain.v1' docs/GCP_EXPLAINABILITY.md
grep -q 'Fail-closed' docs/GCP_EXPLAINABILITY.md
grep -q 'service-account private keys' docs/GCP_EXPLAINABILITY.md
grep -q 'signed URLs' docs/GCP_EXPLAINABILITY.md

echo 'PASS gcp_explain_static'
