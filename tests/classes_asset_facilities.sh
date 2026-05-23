#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=0

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export QUEUEBASH_ROOT="$tmp/q"
_queue_init

fail() {
    echo "[FAIL] $1" >&2
    queue list >&2 || true
    find "$QUEUEBASH_ROOT" -maxdepth 5 -print >&2 || true
    find "$QUEUEBASH_ROOT" -type f -name '*.job' -print -exec cat {} \; >&2 || true
    [[ -f "$QUEUEBASH_ROOT/events.jsonl" ]] && cat "$QUEUEBASH_ROOT/events.jsonl" >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

[[ -f "$QUEUEBASH_ROOT/assets.d/path.sh" ]] || fail "standard path asset helper was not created"

queue assets | grep -q 'path:freespace' || fail "path:freespace facility was not published"
queue assets show path | grep -q 'path:exists' || fail "queue assets show path missing path:exists"

cat > "$QUEUEBASH_ROOT/classes/PATH_OK.env" <<CLASS
CLASS_ALLOW_PARALLEL=1
CLASS_SHARED_ASSETS="path:freespace:$tmp:min_kb=1"
CLASS

queue submit path_ok --class PATH_OK -- bash -c 'echo path-ok-ran' >/dev/null
ok_job="$(grep -l '^JOB_NAME=path_ok$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$ok_job" ]] || fail "path_ok pending job missing"
_queue_class_available "$ok_job" || fail "path:freespace valid asset should be available"

bad_target="$tmp/not_a_directory"
echo "not a directory" > "$bad_target"

cat > "$QUEUEBASH_ROOT/classes/PATH_BLOCK.env" <<CLASS
CLASS_ALLOW_PARALLEL=1
CLASS_SHARED_ASSETS="path:freespace:$bad_target:min_kb=1"
CLASS

queue submit path_block --class PATH_BLOCK -- bash -c 'echo should-not-run' >/dev/null
block_job="$(grep -l '^JOB_NAME=path_block$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$block_job" ]] || fail "path_block pending job missing"

if _queue_class_available "$block_job"; then
    fail "path_block should not be dispatchable with impossible freespace requirement"
fi

[[ -f "$block_job" ]] || fail "path_block should remain pending"
grep -q '"event":"resource_blocked"' "$QUEUEBASH_ROOT/events.jsonl" || fail "resource_blocked event missing"
grep -q 'reason=asset_preflight' "$QUEUEBASH_ROOT/events.jsonl" || fail "asset_preflight reason missing"

cat > "$QUEUEBASH_ROOT/assets.d/gate.sh" <<'PLUGIN'
queue_asset_facilities() {
    echo "gate:open	Checks that QUEUEBASH_ROOT/<target>.open exists"
}

queue_asset_check_gate_open() {
    local token="$1"
    local target="$2"
    shift 2 || true
    [[ -f "$QUEUEBASH_ROOT/$target.open" ]]
}
PLUGIN

queue assets | grep -q 'gate:open' || fail "custom gate:open facility was not published"

cat > "$QUEUEBASH_ROOT/classes/GATE.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_EXCLUSIVE_ASSETS="gate:open:testgate"
CLASS

queue submit gate_job --class GATE -- bash -c 'echo gate-ran' >/dev/null
gate_pending="$(grep -l '^JOB_NAME=gate_job$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$gate_pending" ]] || fail "gate pending job missing"

if _queue_class_available "$gate_pending"; then
    fail "gate_job should be blocked while custom gate is closed"
fi

touch "$QUEUEBASH_ROOT/testgate.open"
_queue_class_available "$gate_pending" || fail "gate_job should be available after custom gate opened"

pass "asset plugins publish facilities to the queue manager"
pass "path:freespace implied asset check uses published facility"
pass "custom nested asset helper is inferred from published facility"

echo
echo "bashqueues asset facility tests: OK"
