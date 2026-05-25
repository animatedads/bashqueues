#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q '_queue_expiry_to_epoch' queuebash.sh
grep -q -- '--expires' queuebash.sh
grep -q 'asset_exception_expired' queuebash.sh
echo '[PASS] time-limited exception overlays are wired'
