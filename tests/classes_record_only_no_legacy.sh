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
    queue classes list >&2 || true
    find "$QUEUEBASH_ROOT/classes" -maxdepth 4 -print -exec sh -c 'test -f "$1" && echo "### $1" && sed -n "1,120p" "$1"' _ {} \; >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

cat > "$tmp/LEGACY.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_SHARED_ASSETS="path:exists:/tmp"
CLASS

if queue classes replace LEGACY "$tmp/LEGACY.env" >/dev/null 2>&1; then
    fail "legacy CLASS_SHARED_ASSETS should be rejected"
fi

cat > "$tmp/LEGACY2.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_EXCLUSIVE_ASSETS="legacy:slot"
CLASS

if queue classes replace LEGACY2 "$tmp/LEGACY2.env" >/dev/null 2>&1; then
    fail "legacy CLASS_EXCLUSIVE_ASSETS should be rejected"
fi

cat > "$tmp/RECORD.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0

queue_class_shared_asset path exists "/tmp"
queue_class_exclusive_claim "record:slot"
CLASS

queue classes replace RECORD "$tmp/RECORD.env" >/dev/null || fail "record class should install"
queue classes validate RECORD >/dev/null || fail "record class should validate"

queue submit record_ok --class RECORD -- bash -c 'echo record-ok' >/dev/null
job="$(grep -l '^JOB_NAME=record_ok$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$job" ]] || fail "record_ok job missing"
_queue_class_available "$job" || fail "record class should dispatch"

if grep -R 'CLASS_SHARED_ASSETS=' "$QUEUEBASH_ROOT/classes/DEFAULT.env" "$QUEUEBASH_ROOT/classes/GITHUB_PUBLISH.env" >/dev/null 2>&1; then
    fail "bundled/default classes should not contain legacy CLASS_SHARED_ASSETS"
fi
if grep -R 'CLASS_EXCLUSIVE_ASSETS=' "$QUEUEBASH_ROOT/classes/DEFAULT.env" "$QUEUEBASH_ROOT/classes/GITHUB_PUBLISH.env" >/dev/null 2>&1; then
    fail "bundled/default classes should not contain legacy CLASS_EXCLUSIVE_ASSETS"
fi

pass "legacy CLASS_SHARED_ASSETS is rejected"
pass "legacy CLASS_EXCLUSIVE_ASSETS is rejected"
pass "record-only class validates and dispatches"
pass "bundled classes are record-only"

echo
echo "bashqueues record-only class tests: OK"
