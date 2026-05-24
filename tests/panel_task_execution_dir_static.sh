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
assert '--chdir' not in src, 'unsupported --chdir still present'
assert 'cwd=d.execution_dir' in src, 'submit cwd not passed'
assert 'cd " + shlex.quote(self.execution_dir)' in src, 'preview cd wrapper missing'
assert 'PWD_AT_SUBMIT' in src, 'execution dir rationale missing'
print("AST/static checks OK")
PY

grep -q 'cd /home/hc3/bashqueues && queue submit publish_git' "$repo_root/README.md" || fail "README missing cd wrapper example"
grep -q 'It does not emit `--chdir`' "$repo_root/README.md" || fail "README missing no --chdir note"

pass "Task Creator no longer emits unsupported --chdir"
pass "Task Creator previews cd wrapper"
pass "Task Creator submits with cwd execution directory"

echo
echo "bashqueues panel task execution directory tests: OK"
