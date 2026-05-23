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
    queue list all >&2 || true
    find "$QUEUEBASH_ROOT" -maxdepth 5 -print -exec sh -c 'test -f "$1" && echo "### $1" && sed -n "1,120p" "$1"' _ {} \; >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

queue submit child --after-success missing_parent -- bash -c 'echo child' >/dev/null
out="$(queue explain child || true)"
grep -q 'Dispatch decision' <<< "$out" || fail "explain missing dispatch section"
grep -q 'missing_parent: waiting (missing)' <<< "$out" || fail "explain missing dependency blocker"

cat > "$QUEUEBASH_ROOT/classes/NEEDS_MISSING.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
queue_class_shared_asset path exists "/definitely/missing/bashqueues/test/path"
CLASS

queue submit blocked_asset --class NEEDS_MISSING -- bash -c 'echo blocked' >/dev/null
out="$(queue explain blocked_asset || true)"
grep -q 'Dispatch decision' <<< "$out" || fail "asset explain missing dispatch section"
grep -q 'class/resource gate rejected job' <<< "$out" || fail "asset explain missing class/resource rejection"
grep -Eq 'path:exists|missing|asset_check' <<< "$out" || fail "asset explain missing plugin output"

queue submit runnable -- bash -c 'echo runnable' >/dev/null
out="$(queue explain runnable || true)"
grep -q 'status:[[:space:]]*runnable' <<< "$out" || fail "runnable job not diagnosed as runnable"

pass "explain reports missing dependency blocker"
pass "explain reports class/resource asset blocker"
pass "explain reports runnable pending jobs"

echo
echo "bashqueues explain dispatch reason tests: OK"
