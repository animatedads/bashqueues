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
    queue mgr help >&2 || true
    queue mgr hints >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

hints="$(queue mgr hints)"
grep -q 'Published helper hints' <<< "$hints" || fail "hints missing header"

if [[ -f "$QUEUEBASH_ROOT/assets.d/net.sh" ]]; then
    grep -q 'net:http_status' <<< "$hints" || fail "hints missing installed net:http_status"
    queue mgr hint net:http_status | grep -q 'Target:' || fail "net hint missing target"
fi

unknown="$(queue mgr hint no:such_facility || true)"
grep -q 'No published helper hint' <<< "$unknown" || fail "unknown hint should fallback"

queue mgr class-create HINTED_CLASS \
  --no-parallel \
  --max-concurrent 1 \
  --exclusive-claim hinted:slot \
  --shared-asset path exists "/tmp" \
  >/dev/null || fail "hinted class create failed"

queue classes validate HINTED_CLASS >/dev/null || fail "hinted class did not validate"

pass "QueueManager lists helper-published hints"
pass "QueueManager shows facility-specific helper hints when installed"
pass "QueueManager still creates record-format classes"

echo
echo "bashqueues QueueManager helper-published hint tests: OK"
