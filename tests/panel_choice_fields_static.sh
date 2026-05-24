#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
panel="$repo_root/queuemgr_panel.py"
changelog="$repo_root/CHANGELOG.md"
doc="$repo_root/docs/QUEUEMGR.md"

fail() {
    echo "[FAIL] $*" >&2
    exit 1
}

grep -q 'def resolve_unique_choice' "$panel" || fail "missing shared unique choice resolver"
grep -q 'startswith(norm)' "$panel" || fail "resolver does not support first unique letters"
grep -q 'norm in normalize_panel_token' "$panel" || fail "resolver does not support unique substring matching"
grep -q 'def prompt_choice' "$panel" || fail "missing shared prompt_choice field helper"
grep -q 'raw == "\*"' "$panel" || fail "prompt_choice does not open list on *"
grep -q 'def select_from_list' "$panel" || fail "missing searchable list selector"
grep -q 'KEY_DOWN' "$panel" || fail "selector missing down-key support"
grep -q 'KEY_UP' "$panel" || fail "selector missing up-key support"

grep -q 'Class for task' "$panel" || fail "Task Creator class selection not routed through shared chooser"
grep -A8 'def select_class_for_task' "$panel" | grep -q 'self.prompt_choice' || fail "class selection still uses old prompt path"
! grep -q 'Available classes' "$panel" || fail "old passive class popup still present"

grep -q 'self.prompt_choice("Job action"' "$panel" || fail "job actions do not use unique command resolver"
grep -q 'self.prompt_choice("Draft action"' "$panel" || fail "draft actions do not use unique command resolver"
grep -q 'self.prompt_choice("Class action"' "$panel" || fail "class actions do not use unique command resolver"
grep -q 'self.prompt_choice("Asset action"' "$panel" || fail "asset actions do not use unique command resolver"
grep -q 'self.prompt_choice("Records action"' "$panel" || fail "record actions do not use unique command resolver"
grep -q 'self.prompt_choice("Runner override"' "$panel" || fail "runner field does not use shared chooser"

grep -q 'Panel field selection' "$doc" || fail "QueueManager docs missing field selection section"
grep -q '0.16.12' "$changelog" || fail "CHANGELOG missing 0.16.12"

python3 -m py_compile "$panel"

echo "[PASS] panel fields use shared unique-letter/search chooser behaviour"
