#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.17.25"' queuebash.sh || fail "queuebash version not 0.17.20"
grep -q '"Tail"' queuemgr_panel.py || fail "Jobs detail tabs do not include Tail"
grep -q 'qrun(\["tail", item.key, "--no-follow"\]' queuemgr_panel.py || fail "Tail RHS does not use non-following queue tail"
grep -q 'action == "tail"' queuemgr_panel.py || fail "job tail action not handled separately"
grep -q 'DETAIL_TABS.index("Tail")' queuemgr_panel.py || fail "job tail does not switch RHS to Tail mode"
grep -q '0.16.24 job tail right-hand pane' docs/QUEUEMGR.md || fail "QUEUEMGR docs missing Tail RHS note"
grep -q 'Jobs Tail right-hand pane' README.md || fail "README missing Tail RHS note"

echo "[PASS] job tail uses a persistent Jobs RHS Tail pane"
