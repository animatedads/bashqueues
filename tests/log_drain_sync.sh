#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=0

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export QUEUEBASH_ROOT="$tmp/q"
mkdir -p "$QUEUEBASH_ROOT"

fail() {
    echo "[FAIL] $1" >&2
    queue list >&2 || true
    find "$QUEUEBASH_ROOT" -type f -name '*.job' -print -exec sh -c 'echo "### $1"; cat "$1"' _ {} \; >&2 || true
    find "$QUEUEBASH_ROOT/logs" -maxdepth 1 -type f -print -exec sh -c 'echo "### $1"; tail -120 "$1"' _ {} \; >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

queue submit drain_order \
    --max-log-size 1M \
    --log-overflow stderr-only \
    -- bash -c '
        echo stdout-start
        echo stderr-start >&2
        for i in $(seq 1 200); do
            echo "stdout-line-$i"
            echo "stderr-line-$i" >&2
        done
        echo stdout-end
        echo stderr-end >&2
        exit 0
    ' >/dev/null

queue run >/dev/null || true

job="$(grep -l '^JOB_NAME=drain_order$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
[[ -n "$job" ]] || fail "drain_order did not finish as done"
grep -q '^EXIT_CODE=0$' "$job" || fail "job did not record exit code 0"

id="$(basename "$job" .job)"
log="$QUEUEBASH_ROOT/logs/$id.log"
[[ -f "$log" ]] || fail "log missing"

grep -q 'stdout-end' "$log" || fail "stdout end missing"
grep -q 'stderr-end' "$log" || fail "stderr end missing"
grep -q '^finished:' "$log" || fail "finished footer missing"
grep -q '^exit_code: 0$' "$log" || fail "exit code footer missing"

last_line="$(tail -n 1 "$log")"
[[ "$last_line" == "exit_code: 0" ]] || fail "footer was not last line; last=$last_line"

finished_line="$(grep -n '^finished:' "$log" | tail -1 | cut -d: -f1)"
stdout_end_line="$(grep -n 'stdout-end' "$log" | tail -1 | cut -d: -f1)"
stderr_end_line="$(grep -n 'stderr-end' "$log" | tail -1 | cut -d: -f1)"
[[ "$stdout_end_line" -lt "$finished_line" ]] || fail "stdout appeared after finished footer"
[[ "$stderr_end_line" -lt "$finished_line" ]] || fail "stderr appeared after finished footer"

if grep -q '^exit_code: 141$' "$log"; then
    fail "SIGPIPE-style exit 141 still present"
fi

if compgen -G "$QUEUEBASH_ROOT/logs/.$id.*.fifo" >/dev/null; then
    fail "stream FIFOs left behind"
fi

pass "stdout/stderr drained before footer"
pass "footer is last line"
pass "no SIGPIPE exit 141"
pass "stream FIFOs cleaned"

echo
echo "bashqueues log drain synchronization tests: OK"
