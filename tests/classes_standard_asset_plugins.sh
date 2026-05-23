#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=0
export QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d"

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export QUEUEBASH_ROOT="$tmp/q"
_queue_init

fail() {
    echo "[FAIL] $1" >&2
    echo "--- assets ---" >&2
    queue assets >&2 || true
    echo "--- validate ---" >&2
    queue assets validate >&2 || true
    find "$QUEUEBASH_ROOT" -maxdepth 5 -print >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

[[ -f "$repo_root/assets.d/net.sh" ]] || fail "bundled net.sh missing"
[[ -f "$repo_root/assets.d/sys.sh" ]] || fail "bundled sys.sh missing"
[[ -f "$QUEUEBASH_ROOT/assets.d/net.sh" ]] || fail "net.sh not installed into queue root"
[[ -f "$QUEUEBASH_ROOT/assets.d/sys.sh" ]] || fail "sys.sh not installed into queue root"

queue assets validate >/dev/null || fail "all bundled asset plugins should validate"

assets_out="$(queue assets)"
grep -q 'net:http_status' <<< "$assets_out" || fail "net:http_status facility missing"
grep -q 'net:tcp_endpoint' <<< "$assets_out" || fail "net:tcp_endpoint facility missing"
grep -q 'net:interface_state' <<< "$assets_out" || fail "net:interface_state facility missing"
grep -q 'sys:memory_available' <<< "$assets_out" || fail "sys:memory_available facility missing"
grep -q 'sys:cpu_load' <<< "$assets_out" || fail "sys:cpu_load facility missing"

# Contract proof without relying on queue assets show formatting.
(
    source "$QUEUEBASH_ROOT/assets.d/net.sh"
    declare -F queue_asset_check_net_http_status >/dev/null
    declare -F queue_asset_check_net_tcp_endpoint >/dev/null
    queue_asset_facilities | grep -q '^net:http_status'
) || fail "net plugin contract check failed"

(
    source "$QUEUEBASH_ROOT/assets.d/sys.sh"
    declare -F queue_asset_check_sys_cpu_load >/dev/null
    declare -F queue_asset_check_sys_memory_available >/dev/null
    queue_asset_facilities | grep -q '^sys:cpu_load'
) || fail "sys plugin contract check failed"

cat > "$QUEUEBASH_ROOT/classes/SYS_OK.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_SHARED_ASSETS="sys:memory_available:0:min_gb=0 sys:process_count:0:max_processes=999999"
CLASS

queue submit sys_ok --class SYS_OK -- bash -c 'echo sys-ok-ran' >/dev/null
job="$(grep -l '^JOB_NAME=sys_ok$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$job" ]] || fail "sys_ok pending job missing"
_queue_class_available "$job" || fail "sys_ok should be dispatchable"

if [[ -d /sys/class/net/lo ]]; then
    cat > "$QUEUEBASH_ROOT/classes/NET_LO.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_SHARED_ASSETS="net:interface_state:lo"
CLASS
    queue submit net_lo --class NET_LO -- bash -c 'echo net-lo-ran' >/dev/null
    net_job="$(grep -l '^JOB_NAME=net_lo$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
    [[ -n "$net_job" ]] || fail "net_lo pending job missing"
    _queue_class_available "$net_job" || fail "net_lo should be dispatchable when lo is up"
fi

pass "network and system plugins install externally with family filenames"
pass "network and system plugins publish valid contracts"
pass "deterministic system/network checks dispatch"

echo
echo "bashqueues standard asset plugin tests: OK"
