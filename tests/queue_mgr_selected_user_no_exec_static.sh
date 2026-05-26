#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
q="$repo_root/queuebash.sh"
readme="$repo_root/README.md"
qdoc="$repo_root/docs/QUEUEMGR.md"
changelog="$repo_root/CHANGELOG.md"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

bash -n "$q" || fail "queuebash syntax"

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' "$q" || fail "queuebash version string missing/malformed"

may_eval_block="$(awk '/^_queue_command_may_evaluate_queue_code\(\)/,/^}/ { print }' "$q")"
[[ -n "$may_eval_block" ]] || fail "_queue_command_may_evaluate_queue_code block missing"
! grep -Eq 'mgr\|manager|queuemgr|qpanel|manager-panel' <<< "$may_eval_block" || fail "queue mgr/panel still marked as queue-code evaluation command"
grep -q 'panel manager itself must remain in the operator/root shell' <<< "$may_eval_block" || fail "manager non-delegation comment missing"

delegate_block="$(awk '/^_queue_delegate_command_to_owner\(\)/,/^}/ { print }' "$q")"
[[ -n "$delegate_block" ]] || fail "_queue_delegate_command_to_owner block missing"
! grep -q 'exec runuser -u "\$owner"' <<< "$delegate_block" || fail "delegation still uses exec runuser"
! grep -q 'exec sudo -u "\$owner"' <<< "$delegate_block" || fail "delegation still uses exec sudo"
grep -q 'runuser -u "\$owner"' <<< "$delegate_block" || fail "runuser delegation call missing"
grep -q 'return "\$?"' <<< "$delegate_block" || fail "delegation return status not preserved"

grep -q 'manager/panel launcher itself is not delegated' "$readme" || fail "README missing manager non-delegation note"
grep -q 'subprocess call, not an `exec`' "$readme" || fail "README missing no-exec delegation note"
grep -q '0.16.13 selected-user panel lifecycle note' "$qdoc" || fail "QUEUEMGR missing 0.16.13 lifecycle note"
grep -q '0.16.13' "$changelog" || fail "CHANGELOG missing 0.16.13"

pass "queue mgr remains in operator shell when a selected queue user is active"
pass "delegated selected-user commands no longer exec-replace the caller shell"
pass "documentation covers selected-user panel lifecycle"

echo
echo "bashqueues selected-user panel no-exec tests: OK"
