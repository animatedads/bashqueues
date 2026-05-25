#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q '_queue_pol_block_reevaluate' queuebash.sh
grep -q 'pol_block_reevaluated' queuebash.sh
grep -q 'reevaluate|re-evaluate|recheck|policy-reevaluate|pol-block-reevaluate' queuebash.sh
echo '[PASS] pol_block re-evaluate command is wired'
