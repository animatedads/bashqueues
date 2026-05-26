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
    find "$QUEUEBASH_ROOT" -maxdepth 4 -name '*.job' -print -exec sh -c 'echo "### $1"; grep -E "^(JOB_ID|JOB_NAME|JOB_CLASS|TIMEOUT|KILL_AFTER|CPU_LIMIT|MEM_LIMIT|BILLING|CLASS_DEFAULTS|RUNNER|RUNNER_USED|EXIT_CODE|RESUBMITTED_FROM)=" "$1" || true' _ {} \; >&2 || true
    exit 1
}

pass(){ echo "[PASS] $1"; }

cat > "$QUEUEBASH_ROOT/classes/SHIFTING.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_DEFAULT_RUNNER=direct
CLASS_DEFAULT_TIMEOUT=10s
CLASS_DEFAULT_KILL_AFTER=1s
CLASS_DEFAULT_BILLING_CYCLES=1
CLASS_DEFAULT_BILLING_UNIT_SECONDS=60
CLASS_DEFAULT_BILLING_GRACE_SECONDS=5
queue_class_shared_asset path exists "/tmp"
CLASS

queue submit shifting --class SHIFTING -- bash -c 'exit 7' >/dev/null
qid="$(basename "$(grep -l '^JOB_NAME=shifting$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)" .job)"

queue run >/dev/null 2>&1 || true
failed="$QUEUEBASH_ROOT/failed/$qid.job"
[[ -f "$failed" ]] || fail "original job did not fail"

grep -q '^TIMEOUT=10s$' "$failed" || fail "original job missing old timeout"
grep -q '^BILLING_GRACE_SECONDS=5$' "$failed" || fail "original job missing old billing grace"

cat > "$QUEUEBASH_ROOT/classes/SHIFTING.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_DEFAULT_RUNNER=direct
CLASS_DEFAULT_TIMEOUT=25s
CLASS_DEFAULT_KILL_AFTER=3s
CLASS_DEFAULT_CPU_LIMIT=25%
CLASS_DEFAULT_MEM_LIMIT=256M
CLASS_DEFAULT_BILLING_CYCLES=2
CLASS_DEFAULT_BILLING_UNIT_SECONDS=120
CLASS_DEFAULT_BILLING_GRACE_SECONDS=10
CLASS_DEFAULT_BILLING_POLICY=shortest-cap-wins
queue_class_shared_asset path exists "/tmp"
CLASS

queue resubmit "$qid" >/dev/null || fail "resubmit failed"

newjob="$(grep -l "^RESUBMITTED_FROM=$qid$" "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$newjob" ]] || fail "resubmitted pending job not found"

grep -q '^JOB_CLASS=SHIFTING$' "$newjob" || fail "resubmitted job lost class"
grep -q '^TIMEOUT=25s$' "$newjob" || fail "resubmitted job did not adopt current TIMEOUT"
grep -q '^KILL_AFTER=3s$' "$newjob" || fail "resubmitted job did not adopt current KILL_AFTER"
grep -q '^CPU_LIMIT=25%$' "$newjob" || fail "resubmitted job did not adopt current CPU_LIMIT"
grep -q '^MEM_LIMIT=256M$' "$newjob" || fail "resubmitted job did not adopt current MEM_LIMIT"
grep -q '^BILLING_CYCLES=2$' "$newjob" || fail "resubmitted job did not adopt current billing cycles"
grep -q '^BILLING_UNIT_SECONDS=120$' "$newjob" || fail "resubmitted job did not adopt current billing unit"
grep -q '^BILLING_GRACE_SECONDS=10$' "$newjob" || fail "resubmitted job did not adopt current billing grace"
grep -q '^BILLING_POLICY=shortest-cap-wins$' "$newjob" || fail "resubmitted job did not adopt current billing policy"
grep -q '^CLASS_DEFAULTS_SOURCE=SHIFTING$' "$newjob" || fail "resubmitted job missing class defaults source"

if grep -q '^TIMEOUT=10s$' "$newjob"; then
    fail "resubmitted job retained stale TIMEOUT=10s"
fi
if grep -q '^BILLING_GRACE_SECONDS=5$' "$newjob"; then
    fail "resubmitted job retained stale billing grace"
fi
if grep -q '^RUNNER_USED=' "$newjob"; then
    fail "resubmitted job retained runtime RUNNER_USED"
fi
if grep -q '^EXIT_CODE=' "$newjob"; then
    fail "resubmitted job retained runtime EXIT_CODE"
fi

pass "resubmit preserves job intent and class name"
pass "resubmit reapplies current class defaults"
pass "resubmit strips stale runtime and old class-derived fields"

echo
echo "bashqueues resubmit current class tests: OK"
