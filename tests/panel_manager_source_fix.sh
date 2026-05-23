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

grep -q '_source_defines_queue' "$repo_root/queuemgr_panel.py" || fail "source verification missing"
grep -q 'NO QUEUE SOURCE' "$repo_root/queuemgr_panel.py" || fail "missing visible source diagnostic"
grep -q 'QUEUEBASH_ALLOW_NONINTERACTIVE=1' "$repo_root/queuemgr_panel.py" || fail "noninteractive source export missing"
grep -q 'command_error_item' "$repo_root/queuemgr_panel.py" || fail "error row helper missing"
grep -q 'panel|qpanel|manager-panel)' "$repo_root/queuebash.sh" || fail "top-level panel command missing"
grep -q 'panel|full|fullscreen|screen)' "$repo_root/queuemgr.sh" || fail "manager panel subcommand missing"

(
    cd "$repo_root"
    python3 - <<'PY'
import queuemgr_panel as p
assert p.QUEUE_SOURCE.endswith("queuebash.sh"), p.QUEUE_SOURCE
rc, out = p.qrun(["version"])
assert rc == 0, (rc, out)
assert "queuebash" in out, out
print("direct qrun ok:", out.splitlines()[0])
PY
) || fail "direct python launch command layer failed"

pass "panel manager verifies queue source"
pass "panel manager exposes command errors"
pass "direct python launch can run queue commands"

echo
echo "bashqueues panel manager source fix tests: OK"
