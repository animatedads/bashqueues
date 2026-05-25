#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=0
export QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d"
export QUEUEBASH_CLASS_SOURCE_DIR="$repo_root/classes"

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
_queue_init

fail() {
    echo "[FAIL] $1" >&2
    queue classes explain TEST_DEFAULTS >&2 || true
    queue list all >&2 || true
    job="$(grep -l '^JOB_NAME=defaulted_job$' "$QUEUEBASH_ROOT"/pending/*.job 2>/dev/null | head -1 || true)"
    [[ -n "$job" ]] && { echo "### job $job" >&2; cat "$job" >&2; }
    exit 1
}

pass(){ echo "[PASS] $1"; }

queue mgr class-create TEST_DEFAULTS \
  --no-parallel \
  --max-concurrent 1 \
  --default-runner systemd \
  --default-cpu-limit '50%' \
  --default-mem-limit 512M \
  --default-max-log-size 1048576 \
  --default-log-policy stderr-only \
  --default-timeout 30s \
  --default-kill-after 5s \
  --default-log-tag '${JOB_NAME}.${JOB_ID}' \
  --default-output-dir '${QUEUEBASH_ROOT}/class_outputs/${JOB_NAME}/${JOB_ID}' \
  --default-env-prefix '${JOB_NAME}_${JOB_ID}' \
  --exclusive-claim test_defaults:slot \
  --shared-asset path exists "/tmp" \
  >/dev/null || fail "class-create with defaults failed"

queue classes validate TEST_DEFAULTS >/dev/null || fail "class with defaults should validate"

explain_class="$(queue classes explain TEST_DEFAULTS || true)"
grep -q 'Class defaults' <<< "$explain_class" || fail "class explain missing defaults"
grep -q 'RUNNER' <<< "$explain_class" || fail "class explain missing RUNNER default"

queue submit defaulted_job --class TEST_DEFAULTS -- bash -c 'echo defaulted' >/dev/null
job="$(grep -l '^JOB_NAME=defaulted_job$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$job" ]] || fail "defaulted job not submitted"
qid="$(basename "$job" .job)"

# Last assignment wins when the job is sourced, but grep also proves the
# appended audit-visible default exists in the record.
grep -q '^RUNNER=systemd$' "$job" || fail "RUNNER default not applied"
grep -q '^CPU_LIMIT=50%$' "$job" || fail "CPU default not applied"
grep -q '^MEM_LIMIT=512M$' "$job" || fail "MEM default not applied"
grep -q '^MAX_LOG_SIZE_BYTES=1048576$' "$job" || fail "log size default not applied"
grep -q '^LOG_OVERFLOW_POLICY=stderr-only$' "$job" || fail "log policy default not applied"
grep -q '^TIMEOUT=30s$' "$job" || fail "timeout default not applied"
grep -q '^KILL_AFTER=5s$' "$job" || fail "kill-after default not applied"
grep -q "^LOG_TAG=defaulted_job\\.$qid$" "$job" || fail "LOG_TAG template not expanded"
grep -q "^OUTPUT_DIR=$QUEUEBASH_ROOT/class_outputs/defaulted_job/$qid$" "$job" || fail "OUTPUT_DIR template not expanded"
grep -q "^ENV_PREFIX=defaulted_job_${qid}$" "$job" || fail "ENV_PREFIX template not expanded"
grep -q '^CLASS_DEFAULTS_SOURCE=TEST_DEFAULTS$' "$job" || fail "class defaults source not recorded"

job_explain="$(queue explain "$qid" || true)"
grep -q 'Class defaults applied' <<< "$job_explain" || fail "job explain missing defaults section"
grep -q 'timeout:[[:space:]]*30s' <<< "$job_explain" || fail "job explain missing timeout"

pass "QueueManager creates classes with default job settings"
pass "class defaults are copied into submitted job records"
pass "JOB_NAME/JOB_ID templates expand at submit time"
pass "explain surfaces inherited class defaults"

echo
echo "bashqueues class default tests: OK"
