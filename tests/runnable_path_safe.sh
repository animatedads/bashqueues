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
    queue assets explain runnable:path_safe >&2 || true
    queue asset-hint runnable:path_safe >&2 || true
    exit 1
}

pass(){ echo "[PASS] $1"; }

queue assets validate runnable >/dev/null || fail "runnable helper should validate"
queue assets | grep -q 'runnable:path_safe' || fail "runnable:path_safe not published"

hint="$(queue asset-hint runnable:path_safe || true)"
grep -q 'Facility: runnable:path_safe' <<< "$hint" || fail "path_safe hint missing"
grep -q 'allow_relative' <<< "$hint" || fail "path_safe hint missing allow_relative"

safe="$tmp/safe.sh"
cat > "$safe" <<'SCRIPT'
#!/usr/bin/env bash
echo ok
SCRIPT

unsafe="$tmp/unsafe.sh"
cat > "$unsafe" <<'SCRIPT'
#!/usr/bin/env bash
cd data
cat input.txt
SCRIPT

(
    source "$QUEUEBASH_ROOT/assets.d/runnable.sh"
    queue_asset_check_runnable_path_safe "$safe" require_shebang=1 >/tmp/safe.out
) || fail "safe script should pass path_safe"

(
    source "$QUEUEBASH_ROOT/assets.d/runnable.sh"
    queue_asset_check_runnable_path_safe "$unsafe" >/tmp/unsafe.out
    exit 1
) || true

grep -q 'relative_path_assumption' /tmp/unsafe.out || fail "unsafe script should report relative_path_assumption"

(
    source "$QUEUEBASH_ROOT/assets.d/runnable.sh"
    queue_asset_check_runnable_path_safe "$unsafe" allow_relative=1 >/tmp/unsafe_allowed.out
) || fail "unsafe script should pass when allow_relative=1"

pass "runnable:path_safe facility is published and validates"
pass "runnable:path_safe hints are available"
pass "runnable:path_safe detects relative path assumptions"

echo
echo "bashqueues runnable path_safe tests: OK"
