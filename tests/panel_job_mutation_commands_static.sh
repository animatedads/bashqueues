#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"

grep -q 'def current_job_fragment' queuemgr_panel.py || fail "selected job context helper missing"
grep -q 'job_context_heads = \["change", "priority", "prio", "kill", "delete", "undelete", "edit"' queuemgr_panel.py || fail "bare job context mutation commands missing"
grep -q '"kill", "delete", "undelete", "edit", "resubmit"' queuemgr_panel.py || fail "job mutation actions missing"
grep -q 'qrun(\["priority", qid, value\]' queuemgr_panel.py || fail "job priority command does not route to queue priority"
grep -q 'qrun(\["cancel", qid\], dry_run=self.dry_run)' queuemgr_panel.py || fail "job edit does not cancel selected job first"
grep -q 'self.copy_job_to_task_draft(qid)' queuemgr_panel.py || fail "job edit/copy does not populate task draft from target qid"
grep -q 'cmd = {"delete": "delete", "cancel": "cancel", "kill": "kill", "undelete": "undelete"' queuemgr_panel.py || fail "job kill/delete/undelete command mapping missing"

grep -q 'job edit.*cancel' docs/QUEUEMGR.md || fail "QueueManager docs do not describe job edit cancel/new draft behaviour"
grep -q 'job change priority 5' README.md || fail "README does not document job mutation commands"

pass "Jobs panel supports typed mutation commands and safe edit-as-cancel-new-draft"
