#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

bash -n "$repo_root/queuebash.sh" || fail "queuebash syntax"
bash -n "$repo_root/queuemgr.sh" || fail "queuemgr syntax"

python3 - <<'PYCHECK'
import ast, os, pathlib
src = pathlib.Path(os.environ['REPO_ROOT']) / 'queuemgr_panel.py'
text = src.read_text()
ast.parse(text)
assert 'delegated_default_home = bool(as_user and not cwd)' in text
assert 'cd "$HOME" && ' in text
assert '<submit user HOME>' in text
assert 'If submit user is set and execution directory is blank' in text
print('AST/static checks OK')
PYCHECK

grep -q 'Delegated submit working directory' "$repo_root/README.md" || fail "README missing delegated cwd docs"
grep -q 'cd "$HOME" && queue submit' "$repo_root/README.md" || fail "README missing HOME submit example"

pass "delegated submit defaults to submit user's HOME"
pass "Task Creator preview uses HOME for blank execution dir"
pass "delegated cwd behaviour is documented"

echo
echo "bashqueues submit user HOME cwd tests: OK"
