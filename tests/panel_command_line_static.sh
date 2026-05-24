#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
panel="$repo_root/queuemgr_panel.py"
readme="$repo_root/README.md"
qdoc="$repo_root/docs/QUEUEMGR.md"
changelog="$repo_root/CHANGELOG.md"

fail() { echo "[FAIL] $*" >&2; exit 1; }

python3 -m py_compile "$panel" || fail "panel does not compile"

grep -q 'def execute_panel_command' "$panel" || fail "missing panel command dispatcher"
grep -q 'def command_prompt' "$panel" || fail "missing command prompt"
grep -q 'def execute_task_command' "$panel" || fail "missing Task Creator command grammar"
grep -q 'def execute_class_command' "$panel" || fail "missing class command grammar"
grep -q 'def execute_maintenance_command' "$panel" || fail "missing maintenance command grammar"
grep -q 'def execute_draft_command' "$panel" || fail "missing draft command grammar"
grep -q 'def switch_view' "$panel" || fail "missing command-driven panel routing"
grep -q 'Type command' "$panel" || fail "footer does not advertise typed commands"
grep -q 'F2 Cmd' "$panel" || fail "footer does not advertise F2 command prompt"
grep -q 'KEY_F2' "$panel" || fail "F2 command key is not handled"
grep -q 'KEY_F3' "$panel" || fail "F3 Queue Users key is not handled"
grep -q 'KEY_F4' "$panel" || fail "F4 Jobs key is not handled"
grep -q 'KEY_F6' "$panel" || fail "F6 dry-run key is not handled"
grep -q 'KEY_F10' "$panel" || fail "F10 action key is not handled"
grep -q 'KEY_F12' "$panel" || fail "F12 quit key is not handled"
grep -q 'self.command_prompt(chr(k))' "$panel" || fail "printable keys do not open command prompt"
grep -q 'task name publish_git' "$qdoc" || fail "QueueManager docs missing Task Creator command examples"
grep -q 'F13-F24' "$qdoc" || fail "QueueManager docs missing extended function key note"
grep -q 'Panel command line' "$readme" || fail "README missing panel command line section"
grep -q '0.16.17' "$changelog" || fail "CHANGELOG missing 0.16.17"

echo "[PASS] panel supports typed commands and function-key operations"
