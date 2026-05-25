#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.17.51"' queuebash.sh || fail "version not 0.17.20"

grep -q '^_queue_mgr_list_facilities_compact()' queuebash.sh || fail "missing _queue_mgr_list_facilities_compact"
grep -q '^_queue_mgr_facility_family()' queuebash.sh || fail "missing _queue_mgr_facility_family"
grep -q '^_queue_mgr_facility_check()' queuebash.sh || fail "missing _queue_mgr_facility_check"
grep -q '^_queue_mgr_wizard_render_preview()' queuebash.sh || fail "missing _queue_mgr_wizard_render_preview"

# The helpers are a fallback contract only; do not restore the legacy text manager.
! grep -q 'QUEUEBASH MANAGER - MAIN MENU' queuebash.sh || fail "legacy manager menu restored"
! grep -q '^_queue_legacy_queuemgr()' queuebash.sh || fail "legacy manager function restored"

# Functional source smoke: facility splitting and preview rendering should work in a sourced shell.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/defaults" <<'D'
CLASS_DEFAULT_RUNNER=auto
IGNORED=value
D
QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_ROOT="$tmp/root" bash -c '
  source ./queuebash.sh
  [[ "$(_queue_mgr_facility_family time:window)" == "time" ]]
  [[ "$(_queue_mgr_facility_check time:window)" == "window" ]]
  _queue_mgr_list_facilities_compact | grep -q "time:window"
  _queue_mgr_wizard_render_preview TESTWIZ 1 0 "$1" "queue_class_shared_asset time window \"overnight\" weekdays=mon-fri weekday_windows=18:00-05:00" > "$2"
  grep -q "CLASS_DEFAULT_RUNNER=auto" "$2"
  grep -q "queue_class_shared_asset time window" "$2"
  bash -n "$2"
' _ "$tmp/defaults" "$tmp/TESTWIZ.env" || fail "helper functional smoke failed"

echo "[PASS] shell class wizard helper contract is present and renders valid class previews"
