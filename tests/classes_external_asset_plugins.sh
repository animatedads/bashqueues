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
    queue list >&2 || true
    find "$QUEUEBASH_ROOT" -maxdepth 5 -print >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

if grep -q $'path:exists\tChecks that a filesystem path exists' "$repo_root/queuebash.sh"; then
    fail "path plugin body is embedded in queuebash.sh"
fi

[[ -f "$repo_root/assets.d/path.sh" ]] || fail "bundled assets.d/path.sh missing"
[[ -f "$QUEUEBASH_ROOT/assets.d/path.sh" ]] || fail "path plugin was not installed to queue root"

queue assets validate >/dev/null || fail "installed external path plugin contract should validate"
queue assets | grep -q 'path:freespace' || fail "path:freespace not published from external plugin"

# Verify local plugin is not overwritten.
echo '# local edit marker' >> "$QUEUEBASH_ROOT/assets.d/path.sh"
_queue_init
grep -q '# local edit marker' "$QUEUEBASH_ROOT/assets.d/path.sh" || fail "local asset plugin edit was overwritten"

cat > "$QUEUEBASH_ROOT/classes/PATH_OK.env" <<CLASS
CLASS_ALLOW_PARALLEL=1
CLASS_SHARED_ASSETS="path:freespace:$tmp:min_kb=1"
CLASS

queue submit path_ok --class PATH_OK -- bash -c 'echo path-ok-ran' >/dev/null
job="$(grep -l '^JOB_NAME=path_ok$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$job" ]] || fail "path_ok pending job missing"
_queue_class_available "$job" || fail "external path plugin did not make path_ok available"

pass "standard path plugin is a separate file"
pass "queue root installs bundled plugin without overwriting local edits"
pass "nested asset preflight loads external plugin"

echo
echo "bashqueues external asset plugin tests: OK"
