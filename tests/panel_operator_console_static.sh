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

grep -q 'self.dry_run' "$repo_root/queuemgr_panel.py" || fail "dry-run toggle missing"
grep -q 'DETAIL_TABS' "$repo_root/queuemgr_panel.py" || fail "right-hand detail tabs missing"
grep -q 'Class policy before exception' "$repo_root/queuemgr_panel.py" || fail "class-before-exception workflow missing"
grep -q 'queue_clear_action' "$repo_root/queuemgr_panel.py" || fail "queue clear action missing"
grep -q 'class_action' "$repo_root/queuemgr_panel.py" || fail "class action menu missing"
grep -q 'asset_action' "$repo_root/queuemgr_panel.py" || fail "asset action menu missing"
grep -q 'job_state_filter' "$repo_root/queuemgr_panel.py" || fail "filtering missing"
grep -q 'Panel manager operator console' "$repo_root/README.md" || fail "README missing operator console docs"

pass "panel manager has dry-run and filters"
pass "panel manager has RHS job tabs and class-before-exception workflow"
pass "panel manager has queue/class/asset actions"

echo
echo "bashqueues panel operator console static tests: OK"
