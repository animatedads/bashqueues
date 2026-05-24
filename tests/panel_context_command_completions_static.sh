#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

grep -q 'def command_completion_choices' queuemgr_panel.py || fail "missing contextual command completion engine"
grep -q 'def choose_command_expansion' queuemgr_panel.py || fail "missing command expansion chooser"
grep -q 'Command (\* list)' queuemgr_panel.py || fail "command prompt does not advertise star completion"
grep -q 'panel:{v.name}' queuemgr_panel.py || fail "panel: command completions missing"
grep -q 'class {resolved_class}' queuemgr_panel.py || fail "class object command expansion missing"
grep -q 'cla MYCLASS hist' queuemgr_panel.py || fail "help/docs example for abbreviated class history missing"
grep -q 'def perform_class_command_action' queuemgr_panel.py || fail "class command action dispatcher missing"
grep -q 'classes", "backups", class_name' queuemgr_panel.py || fail "class history/backups action missing"

grep -q 'panel:classes' docs/QUEUEMGR.md || fail "QUEUEMGR docs missing panel:classes command completion example"
grep -q 'cla mycla hist' docs/QUEUEMGR.md || fail "QUEUEMGR docs missing abbreviated class history example"
grep -q '0.16.19' CHANGELOG.md || fail "CHANGELOG missing 0.16.19 entry"

pass "panel command line supports contextual star completions and class-object action routing"
