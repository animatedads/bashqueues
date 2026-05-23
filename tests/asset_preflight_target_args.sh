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
    echo "--- class ---" >&2
    cat "$QUEUEBASH_ROOT/classes/PROBE.env" >&2 || true
    echo "--- job ---" >&2
    cat "$QUEUEBASH_ROOT/pending/probe.job" >&2 || true
    echo "--- preflight output ---" >&2
    cat /tmp/probe_record.out >&2 || true
    exit 1
}

pass(){ echo "[PASS] $1"; }

cat > "$QUEUEBASH_ROOT/assets.d/probe.sh" <<'PLUGIN'
queue_asset_facilities() {
    echo "probe:target Checks argv contract"
}

queue_asset_check_probe_target() {
    local target="${1:-}"
    shift || true

    if [[ "$target" == "probe:target:good" ]]; then
        echo "asset_check_blocked: probe:target got_full_token target=$target"
        return 9
    fi

    if [[ "$target" != "good" ]]; then
        echo "asset_check_blocked: probe:target bad_target target=$target"
        return 8
    fi

    echo "asset_check_ok: probe:target target=$target args=$*"
}
PLUGIN

queue assets validate probe >/dev/null || fail "probe helper did not validate"

cat > "$QUEUEBASH_ROOT/classes/PROBE.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_DEFAULT_RUNNER=direct
queue_class_shared_asset probe target "good" mode=test
CLASS

cat > "$QUEUEBASH_ROOT/pending/probe.job" <<'JOB'
JOB_ID=probe
JOB_NAME=probe
JOB_CLASS=PROBE
PRIORITY=10
COMMAND=( bash -c 'true' )
JOB

(
    _queue_class_load_for_job "$QUEUEBASH_ROOT/pending/probe.job" >/dev/null
    _queue_asset_implied_preflight_for_class
) >/tmp/probe_record.out || fail "record asset preflight failed"

grep -q 'asset_check_ok: probe:target target=good args=mode=test' /tmp/probe_record.out || fail "record asset did not pass target and params only"

if grep -q 'got_full_token' /tmp/probe_record.out; then
    fail "helper received full asset token as target"
fi

pass "record-format assets pass target as first helper arg"
pass "helpers no longer receive full asset token as target"

echo
echo "bashqueues asset preflight target argv tests: OK"
