#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export QUEUEBASH_ROOT="$tmp/q"
mkdir -p "$QUEUEBASH_ROOT"

fail() {
    echo "[FAIL] $1" >&2
    queue list >&2 || true
    find "$QUEUEBASH_ROOT" -type f -print >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

queue submit clean_done -- bash -c 'echo clean-done' >/dev/null
queue submit clean_fail -- bash -c 'echo clean-fail >&2; exit 3' >/dev/null

queue run >/dev/null || true

done_job="$(grep -l '^JOB_NAME=clean_done$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
fail_job="$(grep -l '^JOB_NAME=clean_fail$' "$QUEUEBASH_ROOT"/failed/*.job | head -1)"
[[ -n "$done_job" ]] || fail "done job missing"
[[ -n "$fail_job" ]] || fail "failed job missing"

done_id="$(basename "$done_job" .job)"
fail_id="$(basename "$fail_job" .job)"

done_log="$(ls "$QUEUEBASH_ROOT/logs/$done_id.log"* | head -1)"
fail_log="$(ls "$QUEUEBASH_ROOT/logs/$fail_id.log"* | head -1)"
[[ -f "$done_log" ]] || fail "done log missing"
[[ -f "$fail_log" ]] || fail "failed log missing"

queue clean-logs --state done --dryrun > "$tmp/dryrun.txt"
grep -q "$done_id" "$tmp/dryrun.txt" || fail "dryrun did not list done log"
[[ -f "$done_log" ]] || fail "dryrun removed done log"

queue clean-logs --state done --force > "$tmp/clean_done.txt"
[[ ! -e "$done_log" ]] || fail "force did not remove done log"
[[ -e "$fail_log" ]] || fail "done-state clean removed failed log"
grep -q '^LOG_CLEANED=1$' "$done_job" || fail "done job did not record LOG_CLEANED"
grep -q '^LOG_CLEANED_AT=' "$done_job" || fail "done job did not record LOG_CLEANED_AT"
grep -q '^LOG_CLEANED_PATH=' "$done_job" || fail "done job did not record LOG_CLEANED_PATH"
grep -q '^LOG_CLEANED_BYTES=' "$done_job" || fail "done job did not record LOG_CLEANED_BYTES"

queue clean-logs --state failed --force > "$tmp/clean_failed.txt"
[[ ! -e "$fail_log" ]] || fail "force did not remove failed log"
grep -q '^LOG_CLEANED=1$' "$fail_job" || fail "failed job did not record LOG_CLEANED"

echo "orphan log" > "$QUEUEBASH_ROOT/logs/orphan123.log"
queue clean-logs --orphan --force > "$tmp/orphan.txt"
[[ ! -e "$QUEUEBASH_ROOT/logs/orphan123.log" ]] || fail "orphan log not removed"

pass "clean-logs dryrun is safe"
pass "clean-logs state filtering works"
grep -q 'log_cleaned' "$QUEUEBASH_ROOT/events.jsonl" || fail "log_cleaned event was not written"

pass "clean-logs orphan cleanup works"
pass "clean-logs records cleanup metadata in job files"

echo
echo "bashqueues clean-logs tests: OK"
