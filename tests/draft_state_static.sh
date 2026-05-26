#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

bash -n "$repo_root/queuebash.sh" || fail "queuebash syntax"
bash -n "$repo_root/queuemgr.sh" || fail "queuemgr syntax"

python3 - <<PY
import ast, pathlib
src = pathlib.Path("$repo_root/queuemgr_panel.py").read_text()
ast.parse(src)
assert 'Drafts' in src
assert 'load_drafts' in src
assert 'draft_action' in src
assert 'create-from-job' in src
print("panel AST/static checks OK")
PY

grep -q '_queue_draft_command' "$repo_root/queuebash.sh" || fail "draft command missing"
grep -q '_queue_draft_create_from_job' "$repo_root/queuebash.sh" || fail "create from job missing"
grep -q '_queue_draft_submit' "$repo_root/queuebash.sh" || fail "draft submit missing"
grep -q 'draft|drafts)' "$repo_root/queuebash.sh" || fail "draft dispatcher missing"
grep -q 'Persistent task drafts' "$repo_root/README.md" || fail "README draft docs missing"
grep -q '0.16.1' "$repo_root/CHANGELOG.md" || fail "CHANGELOG version missing"

pass "queue draft command family exists"
pass "panel Drafts view exists"
pass "draft workflow is documented"

echo
echo "bashqueues draft state static tests: OK"
