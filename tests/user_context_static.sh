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
assert 'default_run_user' in src
assert 'default_submit_user' in src
assert 'submit_user' in src
assert 'as_user=_normalise_optional_user(d.submit_user)' in src
assert 'runuser -u ' in src
print("panel AST/static checks OK")
PY

grep -q 'CLASS_DEFAULT_RUN_USER' "$repo_root/queuebash.sh" || fail "class default run user missing"
grep -q 'CLASS_DEFAULT_SUBMIT_USER' "$repo_root/queuebash.sh" || fail "class default submit user missing"
grep -q 'RUN_USER' "$repo_root/queuebash.sh" || fail "RUN_USER missing"
grep -q 'systemd-run --pipe --wait --collect --uid' "$repo_root/queuebash.sh" || fail "systemd uid support missing"
grep -q '_queue_emit_user_switch_prefix' "$repo_root/queuebash.sh" || fail "direct runner user switch helper missing"
grep -q 'User context and root/operator use' "$repo_root/README.md" || fail "README user context docs missing"

pass "class defaults include run/submit user"
pass "panel exposes class/task user fields"
pass "runner has root user-switch path"

echo
echo "bashqueues user context static tests: OK"
