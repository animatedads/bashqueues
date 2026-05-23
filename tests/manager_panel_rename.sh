#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

bash -n "$repo_root/queuebash.sh" || fail "queuebash syntax"
bash -n "$repo_root/queuemgr.sh" || fail "queuemgr syntax"

python3 - <<PY
import ast, pathlib
ast.parse(pathlib.Path("$repo_root/queuemgr_panel.py").read_text())
PY

grep -q 'panel|qpanel|manager-panel)' "$repo_root/queuebash.sh" || fail "top-level panel dispatch missing"
grep -q 'panel|full|fullscreen|screen)' "$repo_root/queuemgr.sh" || fail "queue mgr panel dispatch missing"
grep -q 'QUEUEBASH PANEL MANAGER' "$repo_root/queuemgr_panel.py" || fail "panel manager header missing"
grep -q 'queue mgr panel' "$repo_root/README.md" || fail "README missing panel command"
grep -q 'queue panel' "$repo_root/README.md" || fail "README missing top-level panel command"

old_file="$repo_root/queuemgr""5250"".py"
if [[ -e "$old_file" ]]; then
    fail "old manager filename still exists"
fi

old_pat='5''250'
if grep -R "$old_pat" "$repo_root/queuebash.sh" "$repo_root/queuemgr.sh" "$repo_root/queuemgr_panel.py" "$repo_root/README.md" >/tmp/panel_refs.out 2>/dev/null; then
    cat /tmp/panel_refs.out >&2
    fail "old UI term remains in user-facing files"
fi

pass "panel manager commands are wired"
pass "panel manager script parses"
pass "old UI term removed from user-facing files"

echo
echo "bashqueues panel manager rename tests: OK"
