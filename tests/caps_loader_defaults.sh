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
    queue classes explain REXX_RUNAWAY >&2 || true
    find "$QUEUEBASH_ROOT/classes" -maxdepth 2 -type f -print -exec sh -c 'echo "### $1"; cat "$1"' _ {} \; >&2 || true
    exit 1
}

pass(){ echo "[PASS] $1"; }

cat > "$QUEUEBASH_ROOT/classes/REXX_RUNAWAY.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=0
CLASS_MAX_CONCURRENT=1

CLASS_DEFAULT_RUNNER=systemd
CLASS_DEFAULT_CPU_LIMIT=50%
CLASS_DEFAULT_MEM_LIMIT=512M
CLASS_DEFAULT_MAX_LOG_SIZE_BYTES=1048576
CLASS_DEFAULT_LOG_OVERFLOW_POLICY=stderr-only
CLASS_DEFAULT_TIMEOUT=30s
CLASS_DEFAULT_KILL_AFTER=5s
CLASS_DEFAULT_LOG_TAG='${JOB_NAME}.${JOB_ID}'
CLASS_DEFAULT_OUTPUT_DIR='${QUEUEBASH_ROOT}/class_outputs/${JOB_NAME}/${JOB_ID}'
CLASS_DEFAULT_ENV_PREFIX='${JOB_NAME}_${JOB_ID}'

queue_class_exclusive_claim "runtime:rexx:runaway"
queue_class_shared_asset path exists "/tmp"

CLASS_DEFAULT_CPU_SECONDS=20
CLASS_DEFAULT_BILLING_UNIT_SECONDS=60
CLASS_DEFAULT_BILLING_CYCLES=1
CLASS_DEFAULT_BILLING_GRACE_SECONDS=5
CLASS_DEFAULT_BILLING_POLICY=shortest-cap-wins
CLASS

queue classes validate REXX_RUNAWAY >/dev/null || fail "REXX_RUNAWAY did not validate"

defaults="$(_queue_class_load_defaults_for_class REXX_RUNAWAY)"
grep -q $'CPU_SECONDS\t20' <<< "$defaults" || fail "loader missing CPU_SECONDS"
grep -q $'BILLING_UNIT_SECONDS\t60' <<< "$defaults" || fail "loader missing billing unit"
grep -q $'BILLING_CYCLES\t1' <<< "$defaults" || fail "loader missing billing cycles"
grep -q $'BILLING_GRACE_SECONDS\t5' <<< "$defaults" || fail "loader missing billing grace"
grep -q $'BILLING_POLICY\tshortest-cap-wins' <<< "$defaults" || fail "loader missing billing policy"

explain="$(queue classes explain REXX_RUNAWAY || true)"
grep -q 'CPU_SECONDS[[:space:]]*20' <<< "$explain" || fail "class explain missing CPU_SECONDS"
grep -q 'BILLING_UNIT_SECONDS[[:space:]]*60' <<< "$explain" || fail "class explain missing billing unit"
grep -q 'BILLING_CYCLES[[:space:]]*1' <<< "$explain" || fail "class explain missing billing cycles"
grep -q 'BILLING_GRACE_SECONDS[[:space:]]*5' <<< "$explain" || fail "class explain missing billing grace"
grep -q 'BILLING_POLICY[[:space:]]*shortest-cap-wins' <<< "$explain" || fail "class explain missing billing policy"

queue submit longrexx --class REXX_RUNAWAY -- bash -c 'echo ok' >/dev/null
job="$(grep -l '^JOB_NAME=longrexx$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$job" ]] || fail "longrexx job not submitted"

grep -q '^CPU_SECONDS=20$' "$job" || fail "job did not receive CPU_SECONDS"
grep -q '^BILLING_UNIT_SECONDS=60$' "$job" || fail "job did not receive billing unit"
grep -q '^BILLING_CYCLES=1$' "$job" || fail "job did not receive billing cycles"
grep -q '^BILLING_GRACE_SECONDS=5$' "$job" || fail "job did not receive billing grace"
grep -q '^BILLING_POLICY=shortest-cap-wins$' "$job" || fail "job did not receive billing policy"

pass "class loader emits execution/cost cap defaults"
pass "class explain displays execution/cost cap defaults"
pass "submitted jobs inherit execution/cost cap defaults"

echo
echo "bashqueues caps loader default tests: OK"
