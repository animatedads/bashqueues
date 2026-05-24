#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

panel="queuemgr_panel.py"
q="queuebash.sh"
changelog="CHANGELOG.md"
qdoc="docs/QUEUEMGR.md"
readme="README.md"

grep -q 'QUEUEBASH_VERSION="0.17.4"' "$q" || fail "queuebash version not 0.17.4"
grep -q '## 0.16.33' "$changelog" || fail "CHANGELOG missing 0.16.33 entry"

grep -q 'if self.view.name == "taskdraft"' "$panel" || fail "panel does not perform Task Creator context-first command handling"
grep -q 'task_context_actions' "$panel" || fail "Task Creator context action list missing"
grep -q '"submit"' "$panel" || fail "submit is not included in Task Creator context actions"
grep -q 'self.execute_task_command(parts)' "$panel" || fail "bare task action does not dispatch to execute_task_command"

grep -q 'Typing `submit` while in Task Creator' "$changelog" || fail "CHANGELOG does not document bare submit context behaviour"
grep -q 'Task Creator context commands' "$qdoc" || fail "QUEUEMGR docs missing Task Creator context commands"
grep -q 'Task Creator context commands' "$readme" || fail "README missing Task Creator context commands"

pass "Task Creator treats bare submit/save/preview as current-task commands"
