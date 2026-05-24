#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

# Test-only parameters must not be offered by the normal generated prompt path.
grep -q 'def class_restriction_param_is_internal' queuemgr_panel.py || fail "missing internal/test parameter filter"
grep -q 'now_epoch' queuemgr_panel.py || fail "now_epoch filter not present"
grep -q 'Skipped test/internal restriction params' queuemgr_panel.py || fail "wizard does not report skipped test/internal params"

# time:window should not advertise now_epoch as a normal production param.
if grep -q $'time:window\t.*params=.*now_epoch=TEST' assets.d/time.sh; then
  fail "time:window hint still advertises now_epoch=TEST as normal params"
fi

# runnable:filesystem should guide directory checks towards executable/traversable=1.
grep -q $'runnable:filesystem\t.*writable=1 executable=1' assets.d/runnable.sh || fail "filesystem hint does not use executable=1"
grep -q 'executable means searchable/traversable' assets.d/runnable.sh || fail "filesystem hint does not explain directory executable semantics"

grep -q 'Must be executable/traversable' queuemgr_panel.py || fail "Class Creator prompt does not explain executable/traversable"
grep -q 'class_restriction_param_default' queuemgr_panel.py || fail "missing safe default logic for generated restriction params"

pass "Class Creator restriction hints avoid test hooks and explain filesystem directory semantics"
