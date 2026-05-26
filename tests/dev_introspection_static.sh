#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q '^_queue_dev_locate()' queuebash.sh
grep -q '^_queue_dev_extract()' queuebash.sh
grep -q '^_queue_dev_patch()' queuebash.sh
grep -q '^_queue_dev_scope()' queuebash.sh
grep -q 'dev|developer)' queuebash.sh
grep -q 'queue dev patch --file FILE --function FUNCTION --source SOURCE' queuebash.sh

echo "[PASS] queue dev introspection command surface is present"
