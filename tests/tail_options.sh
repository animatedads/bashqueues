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
    find "$QUEUEBASH_ROOT" -type f -name '*.job' -print -exec cat {} \; >&2 || true
    find "$QUEUEBASH_ROOT/logs" -maxdepth 1 -type f -print -exec sh -c 'echo "### $1"; cat "$1"' _ {} \; >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

queue submit tailtest -- bash -c 'for i in $(seq 1 20); do echo line-$i; done' >/dev/null
queue run >/dev/null || true

qid="$(basename "$(grep -l '^JOB_NAME=tailtest$' "$QUEUEBASH_ROOT"/done/*.job | head -1)" .job)"
[[ -n "$qid" ]] || fail "tailtest qid not found"

queue tail "$qid" --tail 5 --no-follow > "$tmp/tail5.txt"
grep -q 'exit_code: 0' "$tmp/tail5.txt" || fail "tail5 missing footer exit code"
grep -q 'last 5 lines' "$tmp/tail5.txt" || fail "tail5 header missing line count"
if grep -q 'line-10' "$tmp/tail5.txt"; then
    fail "tail5 included too many old payload lines"
fi

queue tail "$qid" --from-start > "$tmp/full.txt"
grep -q 'line-1' "$tmp/full.txt" || fail "from-start missing first line"
grep -q 'line-20' "$tmp/full.txt" || fail "from-start missing last payload line"
grep -q 'exit_code: 0' "$tmp/full.txt" || fail "from-start missing footer"

queue tail "$qid" -n 3 --no-follow > "$tmp/tail3.txt"
grep -q 'exit_code: 0' "$tmp/tail3.txt" || fail "tail3 missing footer"
if grep -q 'line-15' "$tmp/tail3.txt"; then
    fail "tail3 included too many old payload lines"
fi

if queue tail "$qid" --tail nope --no-follow >/tmp/bad-tail.out 2>/tmp/bad-tail.err; then
    fail "invalid tail count accepted"
fi

pass "tail --tail N limits physical log output"
pass "tail --from-start shows complete log"
pass "tail -n alias works"
pass "tail validates numeric line count"

echo
echo "bashqueues tail option tests: OK"
