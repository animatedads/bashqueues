#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
panel="$repo_root/queuemgr_panel.py"
queuebash="$repo_root/queuebash.sh"
readme="$repo_root/README.md"
qdoc="$repo_root/docs/QUEUEMGR.md"
changelog="$repo_root/CHANGELOG.md"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

python3 -m py_compile "$panel" || fail "panel does not compile"
bash -n "$queuebash" || fail "queuebash syntax check failed"

grep -q 'def draft_create_args' "$panel" || fail "TaskDraft missing draft_create_args"
grep -q 'render_draft_save_command' "$panel" || fail "TaskDraft missing draft save preview"
grep -q 'Item("save", "save as persistent draft")' "$panel" || fail "Task Creator missing save action row"
grep -q 'elif key == "save"' "$panel" || fail "Task Creator save action not handled"
grep -q 'qrun(args, dry_run=self.dry_run, timeout=30)' "$panel" || fail "Task Creator save does not call queue draft create via qrun"
grep -q 'self.task_draft = TaskDraft()' "$panel" || fail "Task Creator submit does not clear working draft"
grep -q 'Task submitted; Task Creator draft cleared' "$panel" || fail "Task Creator submit-clear status missing"

grep -q '_queue_draft_create()' "$queuebash" || fail "queue draft create implementation missing"
grep -q 'create|new|save) _queue_draft_create' "$queuebash" || fail "queue draft create is not wired into dispatcher"
grep -q 'NOT_BEFORE_TEXT' "$queuebash" || fail "saved schedule text not preserved"
grep -q '_queue_now_iso()' "$queuebash" || fail "draft timestamp fallback helper missing"

grep -q 'Task Creator save-as-draft and submit clearing' "$readme" || fail "README missing Task Creator save docs"
grep -q 'queue draft create NAME' "$readme" || fail "README missing queue draft create command"
grep -q 'Task Creator drafts' "$qdoc" || fail "QueueManager docs missing Task Creator drafts section"
grep -q '0.16.15' "$changelog" || fail "CHANGELOG missing 0.16.15"

# Functional smoke: queue draft create should write a draft file without submitting a job.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
out="$(QUEUEBASH_ROOT="$tmp/.queuebash" bash -lc "export QUEUEBASH_ALLOW_NONINTERACTIVE=1; source '$queuebash' >/dev/null 2>&1; queue draft create smoke --priority 7 --class TEST_CLASS --cwd '$tmp' --not-before +10m --retries 2 --backoff 5 --runner auto --max-log-size 1M -- bash -lc 'echo smoke'")"
echo "$out" | grep -q 'Created draft DRAFT-' || fail "queue draft create did not report a created draft"
draft_file="$(echo "$out" | tail -n 1)"
test -f "$draft_file" || fail "draft file was not created"
grep -q '^JOB_NAME=smoke$' "$draft_file" || fail "draft file missing JOB_NAME"
grep -q '^JOB_CLASS=TEST_CLASS$' "$draft_file" || fail "draft file missing JOB_CLASS"
grep -q '^PRIORITY=7$' "$draft_file" || fail "draft file missing priority"
grep -q '^NOT_BEFORE_TEXT=+10m$' "$draft_file" || fail "draft file missing schedule text"
grep -q '^COMMAND=( bash -lc' "$draft_file" || fail "draft file missing command array"

pass "Task Creator can save persistent drafts and clears after successful submit"
