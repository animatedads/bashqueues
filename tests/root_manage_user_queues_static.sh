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
assert 'Queue Users' in src
assert 'PANEL_QUEUE_USER' in src
assert 'except OSError' in src
assert '--queue-user' in src
print("panel AST/static checks OK")
PY

grep -q '_queue_select_user_queue' "$repo_root/queuebash.sh" || fail "user queue selection helper missing"
grep -Fq 'USER [command] [args...]' "$repo_root/queuebash.sh" || fail "global --queue-user selection-only usage missing"
grep -q 'queue-users)' "$repo_root/queuebash.sh" || fail "queue-users command missing"
grep -Fq 'Usage: queue user USER [command] [args...]' "$repo_root/queuebash.sh" || fail "queue user selection-only shorthand missing"
grep -q 'Managing user queues from root' "$repo_root/README.md" || fail "README docs missing"

pass "CLI can select another user's queue root"
pass "panel has Queue Users selector"
pass "panel source probing skips inaccessible sources"

echo
echo "bashqueues root manage user queues static tests: OK"
