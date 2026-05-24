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
    type queuemgr >&2 || true
    queue mgr help >&2 || true
    queuemgr help >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

queue_help="$(queue mgr help)"
bare_help="$(queuemgr help)"
manager_help="$(queue manager help)"

grep -q 'QueueManager is panel-only' <<< "$queue_help" || fail "queue mgr help wrong"
grep -q 'QueueManager is panel-only' <<< "$bare_help" || fail "bare queuemgr help wrong"
grep -q 'QueueManager is panel-only' <<< "$manager_help" || fail "queue manager help wrong"

type queuemgr | grep -q 'queue mgr "$@"' || fail "bare queuemgr is not wrapper"

! type _queue_legacy_queuemgr >/dev/null 2>&1 || fail "legacy manager function still present"
! type _queuemgr_print_commands >/dev/null 2>&1 || fail "legacy manager help function still present"

pass "bare queuemgr routes to panel QueueManager"
pass "queue manager routes to panel QueueManager"
pass "legacy manager code has been removed"

echo
echo "bashqueues QueueManager standalone fix tests: OK"
