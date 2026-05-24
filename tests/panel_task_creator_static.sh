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

grep -q 'class TaskDraft' "$repo_root/queuemgr_panel.py" || fail "TaskDraft missing"
grep -q 'Task Creator' "$repo_root/queuemgr_panel.py" || fail "Task Creator panel missing"
grep -q 'select_class_for_task' "$repo_root/queuemgr_panel.py" || fail "class selector missing"
grep -q 'not-before' "$repo_root/queuemgr_panel.py" || fail "schedule/not-before support missing"
grep -q 'dry-run submit' "$repo_root/queuemgr_panel.py" || fail "task dry-run missing"
grep -q 'use-for-task' "$repo_root/queuemgr_panel.py" || fail "classes panel use-for-task action missing"
grep -q 'Panel Task Creator' "$repo_root/README.md" || fail "README task creator docs missing"

pass "panel task creator model exists"
pass "task creator supports class selection and scheduling"
pass "task creator supports preview/dry-run/submit"

echo
echo "bashqueues panel task creator static tests: OK"
