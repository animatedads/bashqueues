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
    echo "--- backups ---" >&2
    queue assets backups testplug >&2 || true
    find "$QUEUEBASH_ROOT/assets.d" -maxdepth 3 -print -exec sh -c 'test -f "$1" && echo "### $1" && sed -n "1,120p" "$1"' _ {} \; >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

mkdir -p "$QUEUEBASH_ROOT/assets.d"

cat > "$tmp/testplug_v1.sh" <<'PLUGIN'
queue_asset_facilities() {
    echo "testplug:open    v1 check"
}

queue_asset_check_testplug_open() {
    local token="$1"
    local target="$2"
    shift 2 || true
    [[ -f "$QUEUEBASH_ROOT/$target.v1" ]]
}
PLUGIN

cat > "$tmp/testplug_v2.sh" <<'PLUGIN'
queue_asset_facilities() {
    echo "testplug:open    v2 check"
}

queue_asset_check_testplug_open() {
    local token="$1"
    local target="$2"
    shift 2 || true
    [[ -f "$QUEUEBASH_ROOT/$target.v2" ]]
}
PLUGIN

cat > "$tmp/testplug_bad.sh" <<'PLUGIN'
queue_asset_facilities() {
    echo "testplug:open    missing function"
}
PLUGIN

queue assets replace testplug "$tmp/testplug_v1.sh" >/dev/null || fail "initial replace v1 failed"
queue assets validate >/dev/null || fail "v1 plugin should validate"

cat > "$QUEUEBASH_ROOT/classes/TP.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_SHARED_ASSETS="testplug:open:gate"
CLASS

queue submit tp1 --class TP -- bash -c 'echo tp1' >/dev/null
job="$(grep -l '^JOB_NAME=tp1$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$job" ]] || fail "tp1 job missing"

touch "$QUEUEBASH_ROOT/gate.v1"
_queue_class_available "$job" || fail "v1 plugin should accept gate.v1"
rm -f "$QUEUEBASH_ROOT/gate.v1"

if queue assets replace testplug "$tmp/testplug_bad.sh" >/dev/null 2>&1; then
    fail "bad plugin replacement should be rejected"
fi
queue assets validate >/dev/null || fail "rejected bad plugin should not break installed plugin"

queue assets replace testplug "$tmp/testplug_v2.sh" >/dev/null || fail "replace v2 failed"
backup_count="$(queue assets backups testplug | wc -l | tr -d '[:space:]')"
[[ "$backup_count" -ge 1 ]] || fail "backup was not created"

queue submit tp2 --class TP -- bash -c 'echo tp2' >/dev/null
job2="$(grep -l '^JOB_NAME=tp2$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$job2" ]] || fail "tp2 job missing"

touch "$QUEUEBASH_ROOT/gate.v2"
_queue_class_available "$job2" || fail "v2 plugin should accept gate.v2"
rm -f "$QUEUEBASH_ROOT/gate.v2"

queue assets rollback testplug >/dev/null || fail "rollback failed"
queue assets validate >/dev/null || fail "rolled back plugin should validate"

queue submit tp3 --class TP -- bash -c 'echo tp3' >/dev/null
job3="$(grep -l '^JOB_NAME=tp3$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$job3" ]] || fail "tp3 job missing"

touch "$QUEUEBASH_ROOT/gate.v1"
_queue_class_available "$job3" || fail "rolled back v1 plugin should accept gate.v1"

pass "replace validates and installs a new plugin"
pass "bad replacement is rejected without breaking installed plugin"
pass "rollback restores previous working plugin"

echo
echo "bashqueues asset replace/rollback tests: OK"
