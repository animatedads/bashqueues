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
    [[ -f "$QUEUEBASH_ROOT/events.jsonl" ]] && cat "$QUEUEBASH_ROOT/events.jsonl" >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

queue assets validate >/dev/null || fail "standard path helper should validate"
queue assets show path | grep -q 'asset_contract_ok: path:freespace -> queue_asset_check_path_freespace' || fail "path contract details missing"

cat > "$QUEUEBASH_ROOT/assets.d/bad.sh" <<'PLUGIN'
queue_asset_facilities() {
    echo "bad:missing    Publishes a function that does not exist"
}
PLUGIN

if queue assets validate >/dev/null 2>&1; then
    fail "bad helper should fail contract validation"
fi
queue assets | grep -q 'INVALID helper=bad.sh contract_failed' || fail "bad helper not marked invalid in assets list"

cat > "$QUEUEBASH_ROOT/classes/BAD.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_SHARED_ASSETS="bad:missing:target"
CLASS

queue submit bad_job --class BAD -- bash -c 'echo should-not-run' >/dev/null
bad_job="$(grep -l '^JOB_NAME=bad_job$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$bad_job" ]] || fail "bad_job pending file missing"

if _queue_class_available "$bad_job"; then
    fail "bad_job should not be dispatchable with invalid helper contract"
fi

grep -q 'reason=asset_preflight' "$QUEUEBASH_ROOT/events.jsonl" || fail "asset_preflight event missing for contract failure"

cat > "$QUEUEBASH_ROOT/assets.d/good.sh" <<'PLUGIN'
queue_asset_facilities() {
    echo "good:open    Checks that a target file exists under QUEUEBASH_ROOT"
}

queue_asset_check_good_open() {
    local token="$1"
    local target="$2"
    shift 2 || true
    [[ -f "$QUEUEBASH_ROOT/$target" ]]
}
PLUGIN

# Global validation should still fail while bad helper remains.
if queue assets validate >/dev/null 2>&1; then
    fail "global validation should still fail while bad helper exists"
fi

rm -f "$QUEUEBASH_ROOT/assets.d/bad.sh"
queue assets validate >/dev/null || fail "good helper should validate once bad helper is removed"

cat > "$QUEUEBASH_ROOT/classes/GOOD.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_SHARED_ASSETS="good:open:gate.ok"
CLASS

queue submit good_job --class GOOD -- bash -c 'echo good-ran' >/dev/null
good_job="$(grep -l '^JOB_NAME=good_job$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$good_job" ]] || fail "good_job pending file missing"

if _queue_class_available "$good_job"; then
    fail "good_job should be blocked until gate file exists"
fi

touch "$QUEUEBASH_ROOT/gate.ok"
_queue_class_available "$good_job" || fail "good_job should be dispatchable after gate file exists"

pass "standard helper contract validates"
pass "invalid helper contract is detected and blocks dispatch"
pass "valid custom helper publishes and satisfies contract"

echo
echo "bashqueues asset contract tests: OK"
