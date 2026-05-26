#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f assets.d/endpoint.sh ]] || { echo "missing endpoint asset" >&2; exit 1; }
bash -n assets.d/endpoint.sh
bash -n tests/endpoint_governance_smoke.sh
grep -q 'endpoint:jurisdiction_allowed' assets.d/endpoint.sh
grep -q 'endpoint:command_jurisdiction_allowed' assets.d/endpoint.sh
grep -q 'QUEUEBASH_ENDPOINT_REGION_' policies.d/endpoint-jurisdiction/default.env
grep -q 'ENDPOINT_GOVERNANCE' docs/ENDPOINT_GOVERNANCE.md
echo "[PASS] endpoint governance static surface present"
