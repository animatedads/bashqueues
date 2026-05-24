#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

bash -n "$repo_root/queuebash.sh" || fail "queuebash syntax"
bash -n "$repo_root/queuemgr.sh" || fail "queuemgr shim syntax"

python3 - <<PY
import ast, pathlib
ast.parse(pathlib.Path("$repo_root/queuemgr_panel.py").read_text())
PY

grep -q '_queue_manager_panel_entry' "$repo_root/queuebash.sh" || fail "panel manager entry missing"
grep -q 'legacy manager has been removed' "$repo_root/queuebash.sh" || fail "legacy removal message missing"
grep -q 'queue mgr panel' "$repo_root/queuebash.sh" || fail "panel usage missing"
grep -q 'compatibility shim' "$repo_root/queuemgr.sh" || fail "queuemgr shim missing"
grep -q 'queue mgr panel' "$repo_root/queuemgr.sh" || fail "queuemgr shim does not launch panel"

! grep -q 'QUEUEBASH MANAGER - MAIN MENU' "$repo_root/queuebash.sh" || fail "old main menu title still in queuebash.sh"
! grep -q 'Workers / Health / Trace' "$repo_root/queuebash.sh" || fail "old main menu option still in queuebash.sh"
! grep -q 'queuemgr> ' "$repo_root/queuebash.sh" || fail "legacy REPL prompt still in queuebash.sh"
! grep -q '_queuemgr_print_commands' "$repo_root/queuebash.sh" || fail "legacy command printer still in queuebash.sh"
! grep -q '_queuemgr_repl_complete' "$repo_root/queuebash.sh" || fail "legacy repl completion still in queuebash.sh"

grep -q 'QUEUEBASH_SELECTED_ROOT' "$repo_root/queuebash.sh" || fail "queue-user selected root fix missing"
grep -q 'QUEUEBASH_SELECTED_ROOT:-' "$repo_root/queuebash.sh" || fail "_queue_root does not prefer selected root"

pass "queue mgr is panel-only"
pass "legacy main menu removed"
pass "queue-user selected-root fix retained"

echo
echo "bashqueues panel-only manager/no legacy menu tests: OK"
