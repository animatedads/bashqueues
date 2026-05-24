#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

panel="queuemgr_panel.py"
[[ -f "$panel" ]] || fail "missing queuemgr_panel.py"

grep -q 'Item("", "<clear selection: current/default queue>"' "$panel" || fail "Queue Users panel lacks explicit clear/current row"
grep -q 'Queue owner selection cleared; using current/default queue' "$panel" || fail "clear queue-owner status is missing"
pass "panel can clear selected queue owner"

grep -q 'def _delegation_user' "$panel" || fail "delegation helper missing"
grep -q 'runuser delegation is only available to root/operator sessions' "$panel" || fail "non-root delegation diagnostic missing"
grep -q 'wanted == current' "$panel" || fail "current-user runuser suppression missing"
grep -q '_normalise_optional_user' "$panel" || fail "optional user clearing helper missing"
pass "panel suppresses runuser for current user and diagnoses non-root delegation"

grep -q 'current.*none.*clear.*default' docs/QUEUEMGR.md || fail "QueueManager docs do not mention clearing optional user fields"
grep -q 'submit user.*Unix-user delegation' README.md || fail "README does not document submit user delegation distinction"
pass "documentation covers clear/current and submit-user delegation semantics"
