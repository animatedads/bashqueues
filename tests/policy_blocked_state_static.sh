#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q 'QUEUEBASH_VERSION="0.17.34"' queuebash.sh
grep -q 'pol_block' queuebash.sh
grep -q '_queue_job_policy_execution_check' queuebash.sh
grep -q 'No class claims, asset preflight checks, dynamic preflight checks, global claims, or payload launch were attempted' queuebash.sh
grep -q 'resubmit this command with a valid, unexpired, command-bound authorisation' queuebash.sh
bash -n queuebash.sh

echo '[PASS] pol_block terminal state and worker policy gate are wired'
