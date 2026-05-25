#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

bash -n "$repo_root/queuebash.sh" || fail "queuebash syntax"
bash -n "$repo_root/queuemgr.sh" || fail "queuemgr syntax"

out="$(QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc "source '$repo_root/queuebash.sh'; queue version" 2>&1)" || {
  echo "$out" >&2
  fail "queue version failed"
}
echo "$out" | grep -q 'queuebash 0.17.51' || fail "version not 0.17.20"

out="$(QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc "source '$repo_root/queuebash.sh'; QUEUEBASH_PYTHON=/bin/echo queue mgr" 2>&1)" || {
  echo "$out" >&2
  fail "queue mgr failed"
}
! echo "$out" | grep -q 'queue user: no such user: mgr' || fail "queue mgr misparsed as user selector"

out="$(QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc "source '$repo_root/queuebash.sh'; QUEUEBASH_PYTHON=/bin/echo queue mgr panel" 2>&1)" || {
  echo "$out" >&2
  fail "queue mgr panel failed"
}
! echo "$out" | grep -q 'queue user: no such user: mgr' || fail "queue mgr panel misparsed as user selector"

count="$(grep -c '^queue()' "$repo_root/queuebash.sh")"
[[ "$count" -eq 1 ]] || fail "expected exactly one queue() dispatcher, found $count"
grep -A40 '^queue()' "$repo_root/queuebash.sh" | grep -q '_queue_init' || fail "queue() is not dispatcher"
grep -q '^_queue_select_user_queue()' "$repo_root/queuebash.sh" || fail "selector function missing"
grep -q -- '--queue-user|--user-queue)' "$repo_root/queuebash.sh" || fail "exact queue-user parser missing"
grep -q 'QUEUEBASH_SELECTED_ROOT:-' "$repo_root/queuebash.sh" || fail "selected-root preference missing"

pass "queue dispatcher is restored"
pass "queue mgr is not parsed as queue user mgr"
pass "queue-user selected-root parser remains available"

echo
echo "bashqueues queue mgr parser hotfix tests: OK"
