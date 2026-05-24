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
assert 'effective_queue_user = queue_user or PANEL_QUEUE_USER' in src
assert 'args = ["--queue-user", effective_queue_user, *args]' in src
assert 'def resolve_unique_prefix' in src
assert 'def choose_from_list' in src
assert '* for list, prefix accepted' in src
print("panel AST/static checks OK")
PY

grep -q '_queue_draft_now_iso' "$repo_root/queuebash.sh" || fail "draft timestamp fallback missing"
grep -q 'now="$(_queue_draft_now_iso)"' "$repo_root/queuebash.sh" || fail "draft state still uses _queue_now_iso directly"
grep -q '0.16.4' "$repo_root/CHANGELOG.md" || fail "CHANGELOG version missing"
grep -q 'Panel command prefixes and selection popups' "$repo_root/README.md" || fail "README docs missing"

pass "draft state timestamp fallback exists"
pass "panel queue owner is propagated through qrun"
pass "panel action prompts support unique prefixes and list popup"

echo
echo "bashqueues panel owner/drafts/prefix static tests: OK"
