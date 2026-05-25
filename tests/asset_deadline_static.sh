#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source assets.d/deadline.sh

facilities="$(queue_asset_facilities)"
hints="$(queue_asset_hints)"

for token in deadline:monitor deadline:panic; do
    grep -q "^${token}[[:space:]]" <<< "$facilities" || { echo "missing facility $token" >&2; exit 1; }
    grep -q "^${token}[[:space:]]" <<< "$hints" || { echo "missing hint $token" >&2; exit 1; }
    func="queue_asset_check_${token//:/_}"
    declare -F "$func" >/dev/null || { echo "missing check function $func" >&2; exit 1; }
done

grep -q '_queue_deadline_median' assets.d/deadline.sh || { echo "missing median engine" >&2; exit 1; }
grep -q 'CLASS_DEADLINE_FALLBACK_ASSETS' assets.d/deadline.sh || { echo "missing contractual fallback asset support" >&2; exit 1; }
grep -q 'CLASS_DEADLINE_ALLOW_EXTRA_WORKER' assets.d/deadline.sh || { echo "missing deadline extra worker class gate" >&2; exit 1; }
grep -q '_queue_deadline_maybe_start_extra_worker' assets.d/deadline.sh || { echo "missing deadline extra worker starter" >&2; exit 1; }
grep -q 'start_worker=1' docs/DEADLINE_ASSET.md || { echo "missing extra worker documentation" >&2; exit 1; }
grep -q 'pattern=month-end' docs/DEADLINE_ASSET.md || { echo "missing month-end documentation" >&2; exit 1; }

echo "[PASS] deadline dynamic asset is wired"
