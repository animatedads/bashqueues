#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q '_queue_pol_blocked_reevaluate' queuebash.sh
grep -q 'pol_blocked_reevaluated' queuebash.sh
grep -q 'reevaluate|re-evaluate|recheck|policy-reevaluate|pol-block-reevaluate' queuebash.sh
echo '[PASS] pol_blocked re-evaluate command is wired'
