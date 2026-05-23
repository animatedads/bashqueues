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
    find "$QUEUEBASH_ROOT" -maxdepth 5 -type f -print -exec sh -c 'echo "### $1"; sed -n "1,180p" "$1"' _ {} \; >&2 || true
    exit 1
}
pass(){ echo "[PASS] $1"; }

queue assets refresh "$repo_root/assets.d" >/dev/null
queue caps refresh "$repo_root/caps.d" >/dev/null

queue assets validate net_usage >/dev/null || fail "net_usage asset did not validate"
queue caps list | grep -q 'net_usage:job_limit' || fail "net usage cap facility not listed"

counter="$tmp/counter.bytes"
echo 900 > "$counter"

cat > "$QUEUEBASH_ROOT/classes/NETOK.env" <<CLASS
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_DEFAULT_RUNNER=direct
queue_class_shared_asset net_usage allowance "charged" counter_file=$counter allowance_bytes=1K
CLASS

queue submit netok --class NETOK -- bash -c 'true' >/dev/null
job="$(grep -l '^JOB_NAME=netok$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
(
    _queue_class_load_for_job "$job" >/dev/null
    _queue_asset_implied_preflight_for_class
) >/tmp/netok.out || fail "net allowance should pass below allowance"
grep -q 'asset_check_ok: net_usage:allowance' /tmp/netok.out || fail "net allowance ok not reported"

echo 2000 > "$counter"
if (
    _queue_class_load_for_job "$job" >/dev/null
    _queue_asset_implied_preflight_for_class
) >/tmp/netbad.out; then
    fail "net allowance should block above allowance"
fi
grep -q 'asset_check_blocked: net_usage:allowance exceeded' /tmp/netbad.out || fail "net allowance exceeded not reported"

cat > "$QUEUEBASH_ROOT/classes/NETJOB.env" <<CLASS
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_DEFAULT_RUNNER=direct
CLASS_DEFAULT_NET_USAGE_INTERFACE=test0
CLASS_DEFAULT_NET_USAGE_DIRECTION=rx_tx
CLASS_DEFAULT_NET_USAGE_LIMIT_BYTES=50
CLASS_DEFAULT_NET_USAGE_COUNTER_FILE=$counter
CLASS_DEFAULT_NET_USAGE_POLICY=mark-failed
queue_class_shared_asset path exists "/tmp"
CLASS

echo 100 > "$counter"
queue submit netjob --class NETJOB -- bash -c 'true' >/dev/null
job2="$(grep -l '^JOB_NAME=netjob$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
source "$job2"

_queue_net_usage_job_start_record "$job2"
echo 200 > "$counter"
source "$job2"
_queue_append_summary_to_job "$job2" 0 /dev/null

grep -q '^NET_USAGE_START_BYTES=100$' "$job2" || fail "missing start bytes"
grep -q '^NET_USAGE_END_BYTES=200$' "$job2" || fail "missing end bytes"
grep -q '^NET_USAGE_USED_BYTES=100$' "$job2" || fail "missing used bytes"
grep -q '^NET_USAGE_EXCEEDED=1$' "$job2" || fail "missing exceeded flag"
grep -q '^EXIT_CODE=87$' "$job2" || fail "mark-failed did not convert exit code to 87"

pass "net_usage allowance asset blocks class dispatch above allowance"
pass "net usage cap plugin is listed"
pass "runtime net usage accounting can mark jobs failed"

echo
echo "bashqueues net usage plugin tests: OK"
