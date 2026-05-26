#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q 'CLASS_POLICY_MANDATORY_ASSETS' queuebash.sh
grep -q '_queue_policy_lines_merge_unique' queuebash.sh
grep -q '_queue_policy_mandatory_asset_line_to_spec' queuebash.sh
grep -q 'mandatory_policy_asset_blocked' queuebash.sh
grep -q 'Mandatory policy assets are deliberately evaluated outside the normal' queuebash.sh

if [[ -e assets.d/net_usage.sh ]]; then
    echo "FAIL: assets.d/net_usage.sh must remain absent" >&2
    exit 1
fi

echo "[PASS] mandatory policy asset static hooks present"
