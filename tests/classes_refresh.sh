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
    echo "--- refresh stdout ---" >&2
    cat /tmp/refresh.out 2>/dev/null >&2 || true
    echo "--- refresh stderr ---" >&2
    cat /tmp/refresh.err 2>/dev/null >&2 || true
    find "$QUEUEBASH_ROOT/classes" -maxdepth 4 -type f -print -exec sh -c 'echo "### $1"; sed -n "1,140p" "$1"' _ {} \; >&2 || true
    exit 1
}

pass(){ echo "[PASS] $1"; }

src="$tmp/classes"
mkdir -p "$src"

cat > "$src/REFRESHED.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=0
CLASS_MAX_CONCURRENT=1
CLASS_DEFAULT_RUNNER=direct
CLASS_DEFAULT_TIMEOUT=10s
queue_class_shared_asset path exists "/tmp"
CLASS

queue classes refresh "$src" >/tmp/refresh.out 2>/tmp/refresh.err || fail "classes refresh failed"

[[ -f "$QUEUEBASH_ROOT/classes/REFRESHED.env" ]] || fail "refreshed class not installed"
grep -q '^CLASS_DEFAULT_TIMEOUT=10s$' "$QUEUEBASH_ROOT/classes/REFRESHED.env" || fail "refreshed class content wrong"
queue classes validate REFRESHED >/dev/null || fail "refreshed class did not validate"
ls "$QUEUEBASH_ROOT/classes/.backup"/REFRESHED.*.meta >/dev/null 2>&1 || fail "refresh metadata not created"

cat > "$src/REFRESHED.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_DEFAULT_RUNNER=direct
CLASS_DEFAULT_TIMEOUT=20s
queue_class_shared_asset path exists "/tmp"
CLASS

queue classes refresh "$src" >/tmp/refresh.out 2>/tmp/refresh.err || fail "second refresh failed"
grep -q '^CLASS_DEFAULT_TIMEOUT=20s$' "$QUEUEBASH_ROOT/classes/REFRESHED.env" || fail "replacement class not active"
ls "$QUEUEBASH_ROOT/classes/.backup"/REFRESHED.*.env >/dev/null 2>&1 || fail "backup env not created"

cat > "$src/BROKEN.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
this is not valid bash &&
CLASS

if queue classes refresh "$src" >/tmp/refresh.out 2>/tmp/refresh.err; then
    fail "refresh with broken class should fail"
fi

grep -q '^CLASS_DEFAULT_TIMEOUT=20s$' "$QUEUEBASH_ROOT/classes/REFRESHED.env" || fail "broken refresh damaged existing class"

pass "classes refresh installs class definitions"
pass "classes refresh creates metadata and backups"
pass "classes refresh rejects broken definitions without damaging valid classes"

echo
echo "bashqueues class refresh tests: OK"
