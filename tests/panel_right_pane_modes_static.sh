#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }
pass(){ echo "[PASS] $*"; }

grep -q 'QUEUEBASH_VERSION="0.17.19"' queuebash.sh || fail "queuebash version not 0.17.19"
grep -q 'self.class_detail_mode = "explain"' queuemgr_panel.py || fail "class right-pane mode state missing"
grep -q 'def detail_class' queuemgr_panel.py || fail "class detail renderer missing"
grep -q 'mode = getattr(app, "class_detail_mode", "explain")' queuemgr_panel.py || fail "class detail renderer is not mode-driven"
grep -q 'Selected job {qid}; right panel mode' queuemgr_panel.py || fail "job commands do not leave output in right-hand panel"
grep -q 'Selected class {class_name}; right panel mode' queuemgr_panel.py || fail "class commands do not leave output in right-hand panel"
! grep -q 'F9 Copy' queuemgr_panel.py || fail "F9 copy still advertised in panel menu/help"
grep -q 'F9 is not bound; type job <qid> copy' queuemgr_panel.py || fail "F9 copy guard message missing"
grep -q 'job FRAG exception' docs/QUEUEMGR.md || fail "QUEUEMGR docs missing job exception right-pane example"
grep -q '0.16.33' CHANGELOG.md || fail "CHANGELOG missing 0.16.33"
pass "right-hand pane modes persist for job/class output and F9 job copy is disabled"
