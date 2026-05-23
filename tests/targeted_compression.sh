#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=1

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export QUEUEBASH_ROOT="$tmp/q"
mkdir -p "$QUEUEBASH_ROOT"

fail() {
    echo "[FAIL] $1" >&2
    queue list >&2 || true
    find "$QUEUEBASH_ROOT" -maxdepth 3 -print >&2 || true
    find "$QUEUEBASH_ROOT" -type f -name '*.job' -print -exec cat {} \; >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

# Static guard: workers should no longer call the bulk compressor loop.
worker_text="$(awk '/^_queue_worker\(\)/,/^}/ {print}' "$repo_root/queuebash.sh")"
if printf '%s\n' "$worker_text" | grep -q '_queue_compress_completed_logs'; then
    fail "worker still calls bulk _queue_compress_completed_logs"
fi
printf '%s\n' "$worker_text" | grep -q '_queue_maybe_gzip_completed_job_log' || fail "worker missing targeted compression call"

# Create an old completed log that should NOT be touched by a later worker job.
mkdir -p "$QUEUEBASH_ROOT/done" "$QUEUEBASH_ROOT/logs"
cat > "$QUEUEBASH_ROOT/done/old_done.job" <<'JOB'
JOB_ID=old_done
JOB_NAME=old_done
PRIORITY=10
COMMAND=( true )
JOB
echo "old log should stay plain until explicit bulk compression" > "$QUEUEBASH_ROOT/logs/old_done.log"

queue submit compress_ok -- bash -c 'echo hello targeted compression' >/dev/null
queue run >/dev/null || true

new_job="$(grep -l '^JOB_NAME=compress_ok$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
[[ -n "$new_job" ]] || fail "compress_ok job missing from done"

new_id="$(basename "$new_job" .job)"
[[ -f "$QUEUEBASH_ROOT/logs/$new_id.log.gz" ]] || fail "new completed job log was not compressed"
[[ ! -f "$QUEUEBASH_ROOT/logs/$new_id.log" ]] || fail "new plain log still exists after compression"
grep -q '^LOG_COMPRESSED=1$' "$new_job" || fail "new job missing LOG_COMPRESSED metadata"
grep -q '^LOG_PATH=' "$new_job" || fail "new job missing LOG_PATH metadata"

[[ -f "$QUEUEBASH_ROOT/logs/old_done.log" ]] || fail "old log was unexpectedly bulk-compressed by worker"
[[ ! -f "$QUEUEBASH_ROOT/logs/old_done.log.gz" ]] || fail "old gz log unexpectedly created by worker"

queue compress-logs >/dev/null
[[ -f "$QUEUEBASH_ROOT/logs/old_done.log.gz" ]] || fail "explicit queue compress-logs did not compress old log"

pass "worker uses targeted compression"
pass "new completed job log is compressed"
pass "old completed logs are not scanned by worker"
pass "explicit compress-logs still bulk-compresses old logs"

echo
echo "bashqueues targeted compression tests: OK"
