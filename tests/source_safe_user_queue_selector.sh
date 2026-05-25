#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

bash -n "$repo_root/queuebash.sh" || fail "queuebash syntax"

out="$(
    QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc "source '$repo_root/queuebash.sh'; declare -F _queue_select_user_queue >/dev/null; queue version" 2>&1
)" || {
    echo "$out" >&2
    fail "source or queue version failed"
}

echo "$out" | grep -q 'queuebash 0.17.25' || fail "version output missing"
! echo "$out" | grep -q '_queue_select_user_: command not found' || fail "truncated helper executed at source time"

grep -q '^_queue_select_user_queue()' "$repo_root/queuebash.sh" || fail "helper definition missing"
! grep -q '^_queue_select_user_$' "$repo_root/queuebash.sh" || fail "bare truncated helper call remains"

pass "queuebash sources without executing user selector"
pass "user selector helper is correctly named"
pass "truncated helper regression is absent"

echo
echo "bashqueues source-safe user queue selector tests: OK"
