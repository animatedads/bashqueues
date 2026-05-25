#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

bash -n "$repo_root/queuebash.sh" || fail "queuebash syntax"
bash -n "$repo_root/queuemgr.sh" || fail "queuemgr syntax"

REPO_ROOT="$repo_root" python3 - <<'PY'
import ast, pathlib, os
src = (pathlib.Path(os.environ["REPO_ROOT"]) / "queuemgr_panel.py").read_text()
ast.parse(src)
assert 'self.menu_line' in src
assert 'self.safe_addstr(h - 2, 1, self.menu_line' in src
assert 'self.safe_addstr(h - 1, 1, self.status' in src
assert 'body_h = max(6, h - 7)' in src
print("panel AST/static checks OK")
PY

REPO_ROOT="$repo_root" python3 - <<'PY'
import pathlib, os, re
s = (pathlib.Path(os.environ["REPO_ROOT"]) / "queuebash.sh").read_text()
matches = list(re.finditer(r'^queue\(\)\s*\{', s, re.M))
assert len(matches) == 1, len(matches)
q = matches[0].start()
sel = s.index('_queue_select_user_queue "$2"', q)
init = s.index('\n    _queue_init', q)
root = s.index('local root="$(_queue_root)"', q)
assert sel < init < root, (sel, init, root)
print("queue parser order OK")
PY

out="$(QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc "source '$repo_root/queuebash.sh'; queue version" 2>&1)" || {
  echo "$out" >&2
  fail "queue version failed"
}
echo "$out" | grep -q 'queuebash 0.17.51' || fail "version not 0.17.20"

current_user="$(id -un)"
expected_home="$(getent passwd "$current_user" | awk -F: 'NR == 1 { print $6 }')"
out="$(QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc "source '$repo_root/queuebash.sh'; queue user '$current_user' queue-user" 2>&1)" || {
  echo "$out" >&2
  fail "queue user current queue-user failed"
}
echo "$out" | grep -q "queue root:    $expected_home/.queuebash" || {
  echo "$out" >&2
  fail "queue user selected wrong root"
}

pass "queue-user selection happens before queue root initialisation"
pass "panel menu and status lines are separate"
pass "queue user USER selects USER home queue"

echo
echo "bashqueues queue-user root order/footer tests: OK"
