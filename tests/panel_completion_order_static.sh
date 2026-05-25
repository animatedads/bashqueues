#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

grep -q 'QUEUEBASH_VERSION="0.17.15"' queuebash.sh || fail "queuebash version not 0.17.15"
grep -q 'Object/action commands for the current context' queuemgr_panel.py || fail "completion ordering rule missing"
grep -q 'Panels are deliberately appended last' queuemgr_panel.py || fail "panel-bottom completion comment missing"
grep -q 'def add_panel_choices' queuemgr_panel.py || fail "panel choices are not grouped separately"
grep -q 'def finish(include_users: bool = True, include_panels: bool = True)' queuemgr_panel.py || fail "completion finaliser missing"
grep -q 'return finish(include_users=False, include_panels=True)' queuemgr_panel.py || fail "object command completions do not append panels at bottom"

python3 - <<'PY'
from pathlib import Path
s = Path('queuemgr_panel.py').read_text()
needle = 'if self.view.name == "jobs":'
start = s.index(needle, s.index('def command_completion_choices'))
end = s.index('if self.view.name == "maintenance":', start)
block = s[start:end]
if block.index('add(f"job {cur.key} {action}")') > block.index('return finish(include_users=True, include_panels=True)'):
    raise SystemExit('jobs actions are not added before completion finalisation')
finish = s[s.index('def finish'):s.index('head = parts[0]', s.index('def finish'))]
if finish.index('add_user_choices()') > finish.index('add_panel_choices()'):
    raise SystemExit('panels are not appended after user choices')
PY

grep -q 'object/action completions first' docs/QUEUEMGR.md || fail "QueueManager docs missing object-first completion ordering"
grep -q 'panel jumps at the bottom' docs/QUEUEMGR.md || fail "QueueManager docs missing panel-bottom completion ordering"
grep -q '0.16.33' CHANGELOG.md || fail "CHANGELOG missing 0.16.33"

pass "panel command completions list object actions first and panels last"
