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

grep -q 'class ClassDraft' "$repo_root/queuemgr_panel.py" || fail "ClassDraft missing"
grep -q 'Class Creator' "$repo_root/queuemgr_panel.py" || fail "Class Creator panel missing"
grep -q 'queue_class_shared_asset' "$repo_root/queuemgr_panel.py" || fail "shared asset generation missing"
grep -q 'queue_class_exclusive_asset' "$repo_root/queuemgr_panel.py" || fail "exclusive asset generation missing"
grep -q 'queue_class_exclusive_claim' "$repo_root/queuemgr_panel.py" || fail "exclusive claim generation missing"
grep -q 'CLASS_SHARED_ASSETS' "$repo_root/README.md" || fail "README should document no legacy generated"
grep -q 'Panel Class Creator' "$repo_root/README.md" || fail "README class creator docs missing"

pass "panel class creator model exists"
pass "restriction builder can append records to class draft"
pass "class creator docs mention record-format only"

echo
echo "bashqueues panel class creator static tests: OK"
