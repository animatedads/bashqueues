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
tree = ast.parse(src)

# Prove TaskDraft exists and submit_args starts ["submit", self.normalized_name()]
classes = {n.name: n for n in tree.body if isinstance(n, ast.ClassDef)}
assert "TaskDraft" in classes, "TaskDraft missing"
task = classes["TaskDraft"]
method_names = {n.name for n in task.body if isinstance(n, ast.FunctionDef)}
assert "normalized_name" in method_names, "normalized_name missing"
assert "submit_args" in method_names, "submit_args missing"
assert "render_command" in method_names, "render_command missing"

assert 'args: List[str] = ["submit", self.normalized_name()]' in src
assert 'args.extend(["--chdir", self.execution_dir])' in src
assert 're.sub(r"\\\\s+", "_", name)' in src
assert 'args.extend(["--backoff", self.retry_backoff])' in src
assert 'Execution directory' in src
print("AST/static checks OK")
PY

grep -q 'publish git -> publish_git' "$repo_root/README.md" || fail "README missing name normalization doc"
grep -q -- '--chdir /home/hc3/bashqueues' "$repo_root/README.md" || fail "README missing execution directory example"
grep -q 'queue submit <name> \[options\]' "$repo_root/queuemgr_panel.py" || fail "submit syntax comment missing"

pass "Task Creator emits submit name before options"
pass "Task Creator normalizes spaces in job names"
pass "Task Creator supports execution directory"

echo
echo "bashqueues panel task submit dir tests: OK"
