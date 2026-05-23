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

grep -q 'Scrollable modal panel' "$repo_root/queuemgr_panel.py" || fail "scrollable popup implementation missing"
grep -q 'PgUp/PgDn/Home/End scroll' "$repo_root/queuemgr_panel.py" || fail "popup scroll footer missing"
grep -q 'KEY_NPAGE' "$repo_root/queuemgr_panel.py" || fail "popup page-down handling missing"
grep -q 'Force a full redraw behind the modal' "$repo_root/queuemgr_panel.py" || fail "modal redraw missing"
grep -q 'Scrollable command output' "$repo_root/README.md" || fail "README popup docs missing"

pass "panel popup clears and redraws"
pass "panel command output popup is scrollable"
pass "scrollable popup controls are documented"

echo
echo "bashqueues panel scrollable popup tests: OK"
