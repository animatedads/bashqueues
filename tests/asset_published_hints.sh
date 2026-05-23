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
    queue assets >&2 || true
    queue asset-hints >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

cat > "$QUEUEBASH_ROOT/assets.d/demo.sh" <<'PLUGIN'
queue_asset_facilities() {
    echo "demo:thing    Demo facility"
}

queue_asset_hints() {
    echo -e 'demo:thing\ttarget=demo target with : and ,\tparams=alpha=1 beta=x,y,z\texample=queue_class_shared_asset demo thing "a:b,c" alpha=1 beta=x,y,z\tnotes=Demo hint from helper'
}

queue_asset_check_demo_thing() {
    echo "asset_check_ok: demo:thing"
    return 0
}
PLUGIN

queue assets validate >/dev/null || fail "demo helper should validate"

hint="$(queue asset-hint demo:thing)"
grep -q 'Facility: demo:thing' <<< "$hint" || fail "asset-hint missing facility"
grep -q 'demo target with : and ,' <<< "$hint" || fail "asset-hint missing target"
grep -q 'alpha=1 beta=x,y,z' <<< "$hint" || fail "asset-hint missing params"
grep -q 'queue_class_shared_asset demo thing' <<< "$hint" || fail "asset-hint missing example"

queue asset-hints | grep -q 'demo:thing' || fail "asset-hints missing demo"

mgr_hint="$(queue mgr hint demo:thing)"
grep -q 'Facility: demo:thing' <<< "$mgr_hint" || fail "manager did not read helper-published hint"

if [[ -f "$QUEUEBASH_ROOT/assets.d/net.sh" ]]; then
    queue asset-hint net:http_status | grep -q 'Facility: net:http_status' || fail "net:http_status helper hint missing"
    queue mgr hint net:http_status | grep -q 'https://github.com' || fail "manager net hint missing example"
fi

pass "asset helpers publish hint metadata"
pass "core exposes asset-hint and asset-hints"
pass "QueueManager consumes helper-published hints"

echo
echo "bashqueues plugin-published asset hint tests: OK"
