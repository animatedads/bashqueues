#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q 'queue dev flow --file FILE' queuebash.sh
grep -q '_queue_dev_flow()' queuebash.sh
grep -q 'flow|graph|paths)' queuebash.sh
grep -q 'mask_heredocs' queuebash.sh
grep -q 'callees' queuebash.sh
bash -n queuebash.sh

echo '[PASS] queue dev flow static surface present'
