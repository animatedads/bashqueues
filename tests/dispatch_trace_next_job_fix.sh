#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=0
export QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d"
export QUEUEBASH_CLASS_SOURCE_DIR="$repo_root/classes"
export QUEUEBASH_TRACE_DISPATCH=1

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
_queue_init

fail() {
    echo "[FAIL] $1" >&2
    echo "--- list ---" >&2
    queue list all >&2 || true
    echo "--- trace ---" >&2
    queue dispatch-trace >&2 || true
    find "$QUEUEBASH_ROOT" -maxdepth 5 -print -exec sh -c 'test -f "$1" && echo "### $1" && sed -n "1,120p" "$1"' _ {} \; >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

run_queue_bounded() {
    local out="$tmp/queue-run.out"
    local err="$tmp/queue-run.err"
    if ! timeout 30s bash -lc '
        set -euo pipefail
        export QUEUEBASH_ALLOW_NONINTERACTIVE=1
        export QUEUEBASH_RUNNER=direct
        export QUEUEBASH_GZIP_LOGS=0
        export QUEUEBASH_PLUGIN_SOURCE_DIR="$3/assets.d"
        export QUEUEBASH_CLASS_SOURCE_DIR="$3/classes"
        export QUEUEBASH_TRACE_DISPATCH=1
        export QUEUEBASH_ROOT="$1"
        source "$2/queuebash.sh"
        queue run --workers 1
    ' _ "$QUEUEBASH_ROOT" "$repo_root" "$repo_root" >"$out" 2>"$err"; then
        echo "--- bounded queue run stdout ---" >&2
        cat "$out" >&2 || true
        echo "--- bounded queue run stderr ---" >&2
        cat "$err" >&2 || true
        fail "queue run --workers 1 timed out or failed"
    fi
}

queue submit trace_ok -- bash -c 'echo trace-ok' >/dev/null
qid="$(find "$QUEUEBASH_ROOT/pending" -type f -name '*.job' -print0 | xargs -0 grep -l '^JOB_NAME=trace_ok$' | head -1 | xargs -r basename | sed 's/\.job$//')"
[[ -n "$qid" ]] || fail "trace_ok was not submitted"

run_queue_bounded

[[ -f "$QUEUEBASH_ROOT/done/$qid.job" ]] || fail "trace_ok did not move to done"

trace="$(queue dispatch-trace || true)"
grep -q "entered _queue_next_job" <<< "$trace" || fail "trace missing next_job entry"
grep -q "candidate $qid" <<< "$trace" || fail "trace missing candidate"
grep -q "selected $qid" <<< "$trace" || fail "trace missing selected"
grep -q "move pending->running ok $qid" <<< "$trace" || fail "trace missing move ok"
grep -q "claim acquire ok $qid" <<< "$trace" || fail "trace missing claim ok"

pass "next-job trace sees candidate"
pass "worker selects and runs traced job"
pass "trace records move and claim stages"

echo
echo "bashqueues dispatch trace next-job fix tests: OK"
