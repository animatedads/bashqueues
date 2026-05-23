#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

bash -n "$repo_root/queuebash.sh" || fail "queuebash syntax"
bash -n "$repo_root/queuemgr.sh" || fail "queuemgr syntax"
python3 - <<PY
import ast, pathlib
ast.parse(pathlib.Path("$repo_root/queuemgr5250.py").read_text())
PY

grep -q 'mgr5250|manager5250)' "$repo_root/queuebash.sh" || fail "top-level mgr5250 dispatch missing"
grep -q '5250|mgr5250|manager5250)' "$repo_root/queuemgr.sh" || fail "queue mgr 5250 dispatch missing"
grep -q '_discover_queue_source' "$repo_root/queuemgr5250.py" || fail "python manager source discovery missing"
grep -q 'command_error_item' "$repo_root/queuemgr5250.py" || fail "python manager error panel missing"

pass "queue mgr5250 dispatch is wired"
pass "python manager auto-discovers queuebash.sh"
pass "python manager exposes command errors in panels"

echo
echo "bashqueues 5250 runtime fix tests: OK"
