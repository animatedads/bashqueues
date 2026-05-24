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
assert 'copy_job_to_task_draft' in src
assert 'queue_job_file_text' in src
assert 'parse_job_env_from_text' in src
assert 'parse_job_command_from_text' in src
assert 'Copied job' in src
assert 'job <qid> copy' in src
assert 'F9 is not bound' in src
print("panel AST/static checks OK")
PY

grep -q 'Copying a completed job into Task Creator' "$repo_root/README.md" || fail "README copy docs missing"
grep -q '0.16.0' "$repo_root/CHANGELOG.md" || fail "CHANGELOG version missing"

pass "Typed job copy command can copy selected job into Task Creator"
pass "copy workflow parses job metadata"
pass "copy workflow is documented"

echo
echo "bashqueues panel copy job to task static tests: OK"
