#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.17.25"' queuebash.sh || fail "version not 0.17.20"
grep -q 'list-all|all|jobs) _queue_exception_list_all' queuebash.sh || fail "exception list-all dispatcher missing"
grep -q '_queue_exception_list_all()' queuebash.sh || fail "exception list-all function missing"
grep -q 'qrun(\["exception", "list-all"\])' queuemgr_panel.py || fail "Exceptions panel does not use qrun list-all"
grep -q 'Path(QUEUE_ROOT) / "exceptions"' queuemgr_panel.py && fail "Exceptions panel still reads QUEUE_ROOT/exceptions directly"
grep -q 'selected_queue_root_display(self.queue_user)' queuemgr_panel.py || fail "panel header does not show selected owner root"
grep -q '0.16.33 - Exception panel honours selected queue owner' CHANGELOG.md || fail "CHANGELOG missing 0.16.33"

echo "[PASS] Exceptions panel honours selected queue owners"
