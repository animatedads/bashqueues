#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_TRACE_DISPATCH=1
source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
_queue_init

fail() {
    echo "[FAIL] $1" >&2
    queue dispatch-trace >&2 || true
    queue duplicate-qids >&2 || true
    find "$QUEUEBASH_ROOT" -maxdepth 4 -print >&2 || true
    exit 1
}

pass(){ echo "[PASS] $1"; }

qid="TESTQID"
src="$QUEUEBASH_ROOT/pending/$qid.job"
dst="$QUEUEBASH_ROOT/no_such_dir/$qid.job"

cat > "$src" <<'JOB'
JOB_ID=TESTQID
JOB_NAME=test
PRIORITY=10
COMMAND=( true )
JOB

if _queue_move_pending_to_running "$src" "$dst" "$qid" "T"; then
    fail "move helper should fail when destination parent is missing"
fi

trace="$(queue dispatch-trace || true)"
grep -q "move pending->running failed $qid rc=" <<< "$trace" || fail "trace missing move failure"
grep -vq "move pending->running failed $qid rc=0" <<< "$trace" || fail "move failure rc must not be zero"
grep -q "move stderr $qid:" <<< "$trace" || fail "trace missing stderr"
grep -q "move_failure: dst_exists=0" <<< "$trace" || fail "trace missing dst_exists=0"

mkdir -p "$QUEUEBASH_ROOT/done"
cp "$src" "$QUEUEBASH_ROOT/done/$qid.job"
dups="$(queue duplicate-qids || true)"
grep -q "duplicate qid: $qid" <<< "$dups" || fail "duplicate qid not reported"
grep -q "pending" <<< "$dups" || fail "pending duplicate not reported"
grep -q "done" <<< "$dups" || fail "done duplicate not reported"

pass "move failure logs stderr and filesystem diagnostics"
pass "duplicate-qids reports state collisions"

echo
echo "bashqueues move failure diagnostics tests: OK"
