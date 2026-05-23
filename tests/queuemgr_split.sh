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
    echo "--- manager help ---" >&2
    queue mgr help >&2 || true
    echo "--- classes ---" >&2
    queue classes list >&2 || true
    find "$QUEUEBASH_ROOT" -maxdepth 5 -print -exec sh -c 'test -f "$1" && echo "### $1" && sed -n "1,120p" "$1"' _ {} \; >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

[[ -f "$repo_root/queuemgr.sh" ]] || fail "queuemgr.sh missing"

queue mgr help | grep -q 'QueueManager commands' || fail "manager help did not load"

queue mgr class-create TEST_MGR \
  --no-parallel \
  --max-concurrent 1 \
  --exclusive-claim test_mgr:slot \
  --shared-asset path exists "/tmp" \
  >/dev/null || fail "class-create failed"

[[ -f "$QUEUEBASH_ROOT/classes/TEST_MGR.env" ]] || fail "class file not created"

if grep -q 'CLASS_SHARED_ASSETS' "$QUEUEBASH_ROOT/classes/TEST_MGR.env"; then
    fail "manager generated legacy CLASS_SHARED_ASSETS"
fi

grep -q 'queue_class_shared_asset path exists /tmp' "$QUEUEBASH_ROOT/classes/TEST_MGR.env" || fail "record shared asset missing"
grep -q 'queue_class_exclusive_claim test_mgr:slot' "$QUEUEBASH_ROOT/classes/TEST_MGR.env" || fail "exclusive claim missing"

queue classes validate TEST_MGR >/dev/null || fail "manager-created class does not validate"

queue submit mgr_job --class TEST_MGR -- bash -c 'echo mgr-job' >/dev/null
job="$(grep -l '^JOB_NAME=mgr_job$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$job" ]] || fail "mgr_job not submitted"

_queue_class_available "$job" >/dev/null || fail "manager-created class should be available"

pass "QueueManager lazy-loads"
pass "QueueManager creates record-format classes"
pass "manager-created class validates and dispatches"

echo
echo "bashqueues QueueManager split tests: OK"
