#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }
grep -q 'pre-arm' bin/queue-interrogate || fail "pre-arm support missing"
grep -q 'local root_pid=\"\${1:-}\"' bin/queue-interrogate || fail "root_pid unset guard missing"
grep -q 'repeat|campaign' bin/queue-interrogate || fail "repeat/campaign support missing"
grep -q 'diff-runs' bin/queue-interrogate-compile || fail "diff-runs compiler support missing"
grep -q 'merge_cmd' bin/queue-interrogate-compile || fail "merge compiler support missing"
grep -q 'repeat|campaign' queuebash.sh || fail "queue profile repeat dispatch missing"
grep -q 'diff-runs|drift' queuebash.sh || fail "queue profile diff-runs dispatch missing"
grep -q 'interrogate repeat' docs/INTERROGATION_PROFILES.md || fail "campaign docs missing"
echo '[PASS] interrogation campaign static checks pass'
