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
fail(){ echo "[FAIL] $1" >&2; cat /tmp/preflight.out 2>/dev/null >&2 || true; find "$QUEUEBASH_ROOT" -maxdepth 4 -type f -print -exec sh -c 'echo "### $1"; sed -n "1,120p" "$1"' _ {} \; >&2 || true; exit 1; }
pass(){ echo "[PASS] $1"; }

cat > "$QUEUEBASH_ROOT/assets.d/oldstyle.sh" <<'PLUGIN'
queue_asset_facilities() {
    echo "oldstyle:check Checks legacy token/target argv"
}
queue_asset_check_oldstyle_check() {
    local token="$1"
    local target="$2"
    shift 2 || true
    [[ "$token" == "oldstyle:check:thing" ]] || { echo "bad token=$token"; return 1; }
    [[ "$target" == "thing" ]] || { echo "bad target=$target"; return 1; }
    echo "asset_check_ok: oldstyle token=$token target=$target args=$*"
}
PLUGIN
cat > "$QUEUEBASH_ROOT/classes/OLDSTYLE.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
queue_class_shared_asset oldstyle check "thing" mode=test
CLASS
cat > "$QUEUEBASH_ROOT/pending/oldstyle.job" <<'JOB'
JOB_ID=oldstyle
JOB_NAME=oldstyle
JOB_CLASS=OLDSTYLE
COMMAND=( bash -c 'true' )
JOB
( _queue_class_load_for_job "$QUEUEBASH_ROOT/pending/oldstyle.job" >/dev/null; _queue_asset_implied_preflight_for_class ) >/tmp/preflight.out || fail "legacy helper adapter failed"
grep -q 'asset_check_ok: oldstyle token=oldstyle:check:thing target=thing args=mode=test' /tmp/preflight.out || fail "legacy helper did not get token/target"

mkdir -p "$QUEUEBASH_ROOT/logs"
cat > "$QUEUEBASH_ROOT/classes/PATHFREE.env" <<CLASS
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
queue_class_shared_asset path freespace "$QUEUEBASH_ROOT/logs" min_mb=1
CLASS
cat > "$QUEUEBASH_ROOT/pending/pathfree.job" <<'JOB'
JOB_ID=pathfree
JOB_NAME=pathfree
JOB_CLASS=PATHFREE
COMMAND=( bash -c 'true' )
JOB
( _queue_class_load_for_job "$QUEUEBASH_ROOT/pending/pathfree.job" >/dev/null; _queue_asset_implied_preflight_for_class ) >/tmp/preflight.out || fail "path:freespace preflight failed"
grep -q 'asset_check_ok: path:freespace target=' /tmp/preflight.out || fail "path:freespace did not pass"
if grep -q 'not a directory: min_mb=1' /tmp/preflight.out; then fail "path:freespace treated min_mb as target"; fi

pass "legacy token/target helpers still work"
pass "path:freespace receives path as target and min_mb as parameter"
echo
echo "bashqueues asset legacy adapter/path tests: OK"
