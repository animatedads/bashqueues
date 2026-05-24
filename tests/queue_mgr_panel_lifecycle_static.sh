#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

bash -n "$repo_root/queuebash.sh" || fail "queuebash syntax"
bash -n "$repo_root/queuemgr.sh" || fail "queuemgr syntax"
python3 -m py_compile "$repo_root/queuemgr_panel.py" || fail "panel python syntax"

entry_block="$(awk '/^_queue_manager_panel_entry\(\)/,/^}/ { print }' "$repo_root/queuebash.sh")"
[[ -n "$entry_block" ]] || fail "panel entry function missing"
! grep -q 'exec "\$python" "\$panel"' <<< "$entry_block" || fail "panel entry still uses exec and may replace caller shell"
grep -q '"\$python" "\$panel" "\$@"' <<< "$entry_block" || fail "panel entry does not launch python panel normally"

grep -q 'Legacy text/menu QueueManager is disabled' "$repo_root/queuemgr.sh" || fail "queuemgr shim comment missing"
grep -q 'queue mgr panel "\$@"' "$repo_root/queuemgr.sh" || fail "queuemgr shim does not route to panel"

grep -q 'self.safe_addstr(h - 2, 1, self.menu_line' "$repo_root/queuemgr_panel.py" || fail "panel menu footer row missing"
grep -q 'self.safe_addstr(h - 1, 1, self.status' "$repo_root/queuemgr_panel.py" || fail "panel status footer row missing"

grep -q 'launcher must not use `exec`' "$repo_root/docs/QUEUEMGR.md" || fail "QUEUEMGR lifecycle doc missing"
grep -q 'does not use `exec`' "$repo_root/README.md" || fail "README lifecycle doc missing"

pass "queue mgr panel launcher does not replace caller shell"
pass "queuemgr shim routes to panel manager"
pass "panel footer keeps menu/status separate"

echo
echo "bashqueues queue manager panel lifecycle tests: OK"
