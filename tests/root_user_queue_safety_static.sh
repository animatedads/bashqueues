#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

bash -n "$repo_root/queuebash.sh" || fail "queuebash syntax"
bash -n "$repo_root/queuemgr.sh" || fail "queuemgr syntax"

grep -q '_queue_guard_foreign_user_queue_eval' "$repo_root/queuebash.sh" || fail "foreign queue guard missing"
grep -q '_queue_command_may_evaluate_queue_code' "$repo_root/queuebash.sh" || fail "eval command classifier missing"
grep -q '_queue_delegate_command_to_owner' "$repo_root/queuebash.sh" || fail "owner delegation missing"
grep -q 'QUEUEBASH_ROOT_USER_QUEUE_MODE' "$repo_root/queuebash.sh" || fail "refuse/delegate mode missing"
grep -q 'QUEUEBASH_ALLOW_ROOT_USER_QUEUE_EVAL' "$repo_root/queuebash.sh" || fail "escape hatch missing"
grep -q 'run|worker|workers|start|daemon|submit|explain' "$repo_root/queuebash.sh" || fail "run/submit/explain not protected"
grep -q 'class|classes)' "$repo_root/queuebash.sh" || fail "class commands not protected"
grep -q 'asset|assets)' "$repo_root/queuebash.sh" || fail "asset commands not protected"
grep -q 'Root administering user queues safely' "$repo_root/README.md" || fail "README root safety docs missing"

pass "root foreign user queue guard exists"
pass "code-evaluating commands are classified for delegation"
pass "README documents root/user queue safety"

echo
echo "bashqueues root user queue safety static tests: OK"
