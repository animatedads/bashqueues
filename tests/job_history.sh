#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=0
export QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d"
export QUEUEBASH_CLASS_SOURCE_DIR="$repo_root/classes"

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
_queue_init

fail() {
    echo "[FAIL] $1" >&2
    queue list all >&2 || true
    cat "$QUEUEBASH_ROOT/events.jsonl" >&2 || true
    exit 1
}

pass(){ echo "[PASS] $1"; }

queue submit histjob -- bash -c 'exit 17' >/dev/null
qid="$(basename "$(grep -l '^JOB_NAME=histjob$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)" .job)"

queue run >/dev/null 2>&1 || true
[[ -f "$QUEUEBASH_ROOT/failed/$qid.job" ]] || fail "histjob did not fail"

hist="$(queue history "$qid" || true)"
grep -q "QUEUEBASH HISTORY: $qid" <<< "$hist" || fail "history header missing"
grep -q "$qid" <<< "$hist" || fail "history missing qid"
grep -q 'exit=17' <<< "$hist" || fail "history missing exit code"
grep -q 'events:' <<< "$hist" || fail "history missing events"

queue resubmit "$qid" >/dev/null || fail "resubmit failed"
newqid="$(basename "$(grep -l "^RESUBMITTED_FROM=$qid$" "$QUEUEBASH_ROOT"/pending/*.job | head -1)" .job)"

hist2="$(queue history "$newqid" || true)"
grep -q "$qid" <<< "$hist2" || fail "history chain missing old qid"
grep -q "$newqid" <<< "$hist2" || fail "history chain missing new qid"
grep -q "resubmitted from: $qid" <<< "$hist2" || fail "history missing resubmitted-from link"

explain="$(queue explain "$newqid" || true)"
grep -q '^History$' <<< "$explain" || fail "explain missing History section"
grep -q "full history: queue history $newqid" <<< "$explain" || fail "explain missing full history pointer"

pass "queue history shows lifecycle and exit codes"
pass "queue history follows resubmit chain"
pass "queue explain links to full history"

echo
echo "bashqueues job history tests: OK"
