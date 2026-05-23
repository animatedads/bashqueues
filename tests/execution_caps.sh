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
    queue classes explain CAPS_TEST >&2 || true
    job="$(grep -l '^JOB_NAME=capped_job$' "$QUEUEBASH_ROOT"/pending/*.job 2>/dev/null | head -1 || true)"
    [[ -n "$job" ]] && { echo "### job $job" >&2; cat "$job" >&2; queue explain "$(basename "$job" .job)" >&2 || true; }
    exit 1
}

pass(){ echo "[PASS] $1"; }

[[ "$(_queue_duration_to_seconds 30s)" == "30" ]] || fail "30s duration parse failed"
[[ "$(_queue_duration_to_seconds 2m)" == "120" ]] || fail "2m duration parse failed"
[[ "$(_queue_caps_billing_timeout_seconds 60 1 5)" == "55" ]] || fail "billing timeout 60*1-5 should be 55"
[[ "$(_queue_caps_effective_timeout_seconds_from_values 30s 60 1 5)" == "30" ]] || fail "explicit 30s should beat billing 55s"
[[ "$(_queue_caps_effective_timeout_seconds_from_values 120s 60 1 5)" == "55" ]] || fail "billing 55s should beat explicit 120s"

queue mgr class-create CAPS_TEST \
  --no-parallel \
  --max-concurrent 1 \
  --default-runner direct \
  --default-timeout 120s \
  --default-kill-after 5s \
  --default-cpu-seconds 20 \
  --default-billing-unit-seconds 60 \
  --default-billing-cycles 1 \
  --default-billing-grace-seconds 5 \
  --default-billing-policy shortest-cap-wins \
  --shared-asset path exists "/tmp" \
  >/dev/null || fail "class-create caps failed"

queue classes validate CAPS_TEST >/dev/null || fail "CAPS_TEST did not validate"

queue submit capped_job --class CAPS_TEST -- bash -c 'echo capped' >/dev/null
job="$(grep -l '^JOB_NAME=capped_job$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$job" ]] || fail "capped job not submitted"
qid="$(basename "$job" .job)"

grep -q '^TIMEOUT=120s$' "$job" || fail "TIMEOUT default missing"
grep -q '^CPU_SECONDS=20$' "$job" || fail "CPU_SECONDS default missing"
grep -q '^BILLING_UNIT_SECONDS=60$' "$job" || fail "billing unit missing"
grep -q '^BILLING_CYCLES=1$' "$job" || fail "billing cycles missing"
grep -q '^BILLING_GRACE_SECONDS=5$' "$job" || fail "billing grace missing"

(
    source "$job"
    eff="$(_queue_caps_effective_timeout_for_current_job)"
    [[ "$eff" == "55s" ]] || { echo "expected effective timeout 55s, got $eff" >&2; exit 1; }
) || fail "effective timeout from job should be 55s"

explain="$(queue explain "$qid" || true)"
grep -q 'Execution caps' <<< "$explain" || fail "explain missing caps section"
grep -q 'billing timeout:[[:space:]]*55s' <<< "$explain" || fail "explain missing billing timeout 55s"
grep -q 'effective timeout:[[:space:]]*55s' <<< "$explain" || fail "explain missing effective timeout 55s"
grep -q 'CPU seconds:[[:space:]]*20' <<< "$explain" || fail "explain missing CPU seconds"

pass "duration and billing cap maths work"
pass "class cap defaults are copied into job records"
pass "shortest-cap-wins derives effective timeout"
pass "queue explain shows execution caps"

echo
echo "bashqueues execution caps tests: OK"
