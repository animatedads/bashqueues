#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
panel="$repo_root/queuemgr_panel.py"
readme="$repo_root/README.md"
qdoc="$repo_root/docs/QUEUEMGR.md"
changelog="$repo_root/CHANGELOG.md"

fail() { echo "[FAIL] $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.17.25"' "$repo_root/queuebash.sh" || fail "queuebash version not 0.17.20"

grep -q 'def execute_job_command' "$panel" || fail "panel lacks typed job command handler"
grep -q 'def select_job_by_fragment' "$panel" || fail "panel lacks QID fragment selector"
grep -q 'job_heads = \["job", "jobs", "qid", "history", "hist", "show", "tail", "explain"\]' "$panel" || fail "job/history heads not routed through command line"
grep -q 'self.detail_tab_index = self.DETAIL_TABS.index("History")' "$panel" || fail "history command does not switch RHS detail tab to History"
grep -q 'qrun(\[cmd, qid\]' "$panel" || fail "job history/show/tail command does not execute against resolved QID"

grep -q 'self.view_hotkeys' "$panel" || fail "panel does not define view hotkeys"
grep -q 'label = f" \[{hotkey}\] {v.title} "' "$panel" || fail "tab labels are not hotkey labelled"
if grep -q 'label = f" {key}:{v.title} "' "$panel"; then
    fail "numeric panel tab labels are still present"
fi
if grep -q 'key = "0" if i == 9 else str(i + 1)' "$panel"; then
    fail "numeric panel tab key generation is still present"
fi

grep -q 'job 1798231 history' "$readme" || fail "README lacks job history typed-command example"
grep -q 'job 1798231 history' "$qdoc" || fail "QueueManager docs lack job history typed-command example"
grep -q 'Number keys are no longer used for panel selection' "$qdoc" || fail "QueueManager docs do not document removal of numbered top-level tabs"
grep -q '0.16.18' "$changelog" || fail "CHANGELOG missing 0.16.18"

echo "[PASS] panel supports job-fragment history commands and hotkey-labelled tabs"
