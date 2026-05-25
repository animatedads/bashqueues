#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

grep -q 'QUEUEBASH_VERSION="0.17.16"' queuebash.sh || fail "version not 0.17.16"
! grep -q 'ViewState("builder"' queuemgr_panel.py || fail "Restriction Builder view still registered"
! grep -q '"builder": "B"' queuemgr_panel.py || fail "Restriction Builder hotkey still registered"
! grep -q '"builder": \[' queuemgr_panel.py || fail "Restriction Builder command alias still registered"
grep -q 'header = f"QUEUEBASH PANEL MANAGER' queuemgr_panel.py || fail "panel header is not single clipped string"
grep -q 'remaining = w - x - 1' queuemgr_panel.py || fail "panel tab drawing is not width-clipped"
[[ ! -e assets.d/net_usage.sh ]] || fail "assets.d/net_usage.sh must not be present"

grep -q 'Restriction Builder is temporarily removed' docs/QUEUEMGR.md README.md queuemgr_panel.py || fail "temporary removal not documented"

pass "Restriction Builder is removed from active panel order and header/tabs are clipped"
