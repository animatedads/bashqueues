#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PANEL="$ROOT/queuemgr_panel.py"

fail() { echo "[FAIL] $*" >&2; exit 1; }

grep -q 'elif k == curses.KEY_DC:' "$PANEL" || fail "main loop does not bind Delete/KEY_DC"
grep -q 'def clear_current_editor_field' "$PANEL" || fail "missing central Delete field-clear dispatcher"
grep -q 'def clear_current_task_field' "$PANEL" || fail "missing Task Creator field clear helper"
grep -q 'def clear_current_class_field' "$PANEL" || fail "missing Class Creator field clear helper"
grep -q '"security_reason": "security_reason"' "$PANEL" || fail "Task Creator security reason is not clearable"
grep -q '"authorisation": "authorisation_code"' "$PANEL" || fail "Task Creator authorisation code is not clearable"
grep -q 'd.priority = "10"' "$PANEL" || fail "Task Creator priority does not reset safely"
grep -q 'd.retries = "0"' "$PANEL" || fail "Task Creator retries does not reset safely"
grep -q 'd.default_runner = "auto"' "$PANEL" || fail "Class Creator default runner does not reset safely"
grep -q 'Delete on an inactive Class/Task Creator field clears that field' "$PANEL" || fail "help text does not document Delete clearing"

python3 -m py_compile "$PANEL"
echo "[PASS] Queue Manager Delete clears inactive Task/Class Creator fields"
