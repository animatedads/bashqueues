#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -q '0.18.139 BOB28 status JSON carry-forward and schema hardening' README.md || fail "README entry missing"
grep -q '0.18.139 BOB28 status JSON carry-forward and schema hardening' CHANGELOG.md || fail "CHANGELOG entry missing"
grep -q 'QUEUEBASH_VERSION="0.18.139"' queuebash.sh || fail "version not bumped"
grep -q '_queue_status_help_json' queuebash.sh || fail "status JSON help helper missing"
grep -q 'queuebash.status_help.v1' queuebash.sh || fail "status help schema missing"
grep -q 'queuebash.job_status.v1' queuebash.sh || fail "job status schema missing"
grep -q 'status_missing_target' queuebash.sh || fail "missing target JSON code missing"
grep -q 'status_target_not_found' queuebash.sh || fail "not found JSON code missing"
grep -q 'status_tail_not_numeric' queuebash.sh || fail "tail numeric JSON code missing"

echo "bob28 status JSON carry-forward static checks: OK"
