#!/usr/bin/env bash
set -eo pipefail
ROOT="${TMPDIR:-/tmp}/queuebash_waiting_followup_$$"
rm -rf "$ROOT"
export QUEUEBASH_ROOT="$ROOT"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
# shellcheck disable=SC1091
source ./queuebash.sh
queue submit mig-wait --class DB_MIGRATION -- bash -lc 'echo migrate' >/dev/null
queue run >/tmp/queuebash_waiting_run_$$.out 2>&1 || true
stats="$(queue stats --json)"
python3 - <<PY
import json,sys
s=json.loads('''$stats''')
assert s['states']['waiting']==1, s
assert s['states']['pending']==0, s
assert s['states']['running']==0, s
assert s['states']['interrupted']==0, s
PY
job="$(find "$ROOT/waiting" -type f -name '*.job' | head -1)"
[[ -n "$job" ]]
case "$job" in "$ROOT"/waiting/p*/*.job) ;; *) echo "waiting job not priority bucketed: $job" >&2; exit 1 ;; esac
qid="$(basename "$job" .job)"
set +e
queue explain "$qid" > /tmp/queuebash_waiting_explain_$$.out
explain_rc=$?
set -e
[[ "$explain_rc" -eq 0 ]]
 grep -q '^state: *waiting' /tmp/queuebash_waiting_explain_$$.out
 grep -q 'wait reason:' /tmp/queuebash_waiting_explain_$$.out
queue explain "$qid" --json > /tmp/queuebash_waiting_explain_$$.json
python3 -c 'import json,sys; o=json.load(open(sys.argv[1])); assert o["state"]=="waiting"; assert o["wait"]["reason"]' /tmp/queuebash_waiting_explain_$$.json
queue pause "$qid" >/tmp/queuebash_waiting_pause_$$.out
queue stats --json | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["states"]["paused"]==1 and o["states"]["waiting"]==0, o'
rm -rf "$ROOT" /tmp/queuebash_waiting_run_$$.out /tmp/queuebash_waiting_pause_$$.out /tmp/queuebash_waiting_explain_$$.out /tmp/queuebash_waiting_explain_$$.json
