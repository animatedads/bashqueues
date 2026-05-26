#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
grep -q 'def draw_tabs(self, y: int) -> int:' queuemgr_panel.py || fail "draw_tabs does not report consumed rows"
grep -q 'max_rows = 2' queuemgr_panel.py || fail "top-level tabs are not capped/wrapped over two rows"
grep -q 'tab_rows = self.draw_tabs(1)' queuemgr_panel.py || fail "panel body layout does not use tab row count"
grep -q 'top = filter_y + 1' queuemgr_panel.py || fail "panel body does not move down after wrapped tabs"

echo "[PASS] QueueManager top tabs wrap over two rows"
