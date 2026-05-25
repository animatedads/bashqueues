#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q 'QUEUEBASH_SUBMIT_REASON_DEFAULT' queuebash.sh
grep -q 'QUEUEBASH_SUBMIT_REASON_DEFAULT' tests/selftest.sh
grep -q 'QUEUEBASH_SUBMIT_REASON_DEFAULT' publish_to_github.sh
grep -q 'noninteractive submit default reason' README.md

echo '[PASS] noninteractive submit default reason hooks are present'
