#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT_DIR"

grep -q 'queue cleared' queuebash.sh
grep -q '_queue_cleared_jobs_list' queuebash.sh
grep -q '_queue_job_mark_cleared' queuebash.sh
grep -q 'JOB_CLEARED_AT' queuebash.sh
grep -q '"clearance"' queuebash.sh
bash -n queuebash.sh

echo '[PASS] cleared jobs static surface present'
