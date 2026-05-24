#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }
python3 -m py_compile "$repo_root/queuemgr_panel.py" || fail "queuemgr_panel.py does not compile"
bash -n "$repo_root/queuemgr.sh" || fail "queuemgr.sh syntax failed"
bash -n "$repo_root/queuebash.sh" || fail "queuebash.sh syntax failed"
grep -q 'queue mgr panel' "$repo_root/README.md" || fail "README missing panel manager docs"
! grep -q 'ViewState("builder"' "$repo_root/queuemgr_panel.py" || fail "restriction builder view should be removed"
grep -q 'exception add' "$repo_root/queuemgr_panel.py" || fail "manager missing exception workflow"
grep -q 'QUEUEBASH_COMMAND_ARG_1_ABSPATH' "$repo_root/queuemgr_panel.py" || fail "manager missing selectable variables"
pass "panel manager compiles"
pass "panel manager is documented"
pass "panel manager includes panels and exceptions; restriction builder is removed"
echo
echo "bashqueues panel manager static tests: OK"
