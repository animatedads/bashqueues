#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
export QUEUEBASH_ROOT="$ROOT"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
# shellcheck source=/dev/null
source "$SCRIPT_DIR/queuebash.sh"

qid="wait_lookup_$$"
mkdir -p "$ROOT/waiting/p0999999990"
cat > "$ROOT/waiting/p0999999990/$qid.job" <<JOB
JOB_ID='$qid'
JOB_NAME='waiting-lookup-demo'
JOB_CLASS='DB_MIGRATION'
PRIORITY='10'
SUBMITTED_AT='2026-06-05T21:00:00+01:00'
PWD_AT_SUBMIT='$PWD'
WAIT_REASON='maintenance_window_closed'
WAIT_DETAIL='maintenance window is not currently open'
WAIT_LAST_PREFLIGHT='2026-06-05T21:14:03+01:00'
WAIT_NEXT_CHECK='2026-06-05T21:15:03+01:00'
WAIT_OPERATOR_ACTION='wait_or_use_approved_override'
COMMAND=( bash -lc 'echo wait' )
JOB

out="$(queue list --state waiting)"
printf '%s\n' "$out" | grep -q "$qid"
wait_out="$(queue waiting)"
printf '%s\n' "$wait_out" | grep -q 'Pending jobs waiting on dependencies'
printf '%s\n' "$wait_out" | grep -q 'Jobs in waiting state'
printf '%s\n' "$wait_out" | grep -q "$qid"
printf '%s\n' "$wait_out" | grep -q 'maintenance_window_closed'
status_json="$(queue status "$qid" --json)"
printf '%s\n' "$status_json" | grep -q '"state":"waiting"'
printf '%s\n' "$status_json" | grep -q '"dispatch_diagnosis"'
printf '%s\n' "$status_json" | grep -q '"status":"waiting"'
queue authorise "$qid" --code ZZ999 --reason test >/tmp/qb-authorise-waiting.out
cat /tmp/qb-authorise-waiting.out | grep -qi 'authorised'
grep -q 'SECURITY_AUTHORISATION_CODE' "$ROOT/waiting/p0999999990/$qid.job"
