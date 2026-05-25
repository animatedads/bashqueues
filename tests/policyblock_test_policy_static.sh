#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q 'QUEUEBASH_VERSION="0.17.51"' queuebash.sh
grep -q 'CLASS_POLICY_BLOCK_CLASS_NAMES' queuebash.sh
grep -q "class '\${JOB_CLASS}' is policy-blocked" queuebash.sh
test -f policies.d/class-statement/policyblock-test.env
grep -q 'CLASS_POLICY_BLOCK_CLASS_NAMES="POLICYBLOCKED"' policies.d/class-statement/policyblock-test.env
test -f classes/POLICYBLOCKED.env
grep -q 'bashqueues class: POLICYBLOCKED' classes/POLICYBLOCKED.env
test -f docs/POLICYBLOCK_TEST.md
bash -n queuebash.sh

echo '[PASS] policyblock-test class policy hook is wired'
