#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_RUNNER=direct QUEUEBASH_GZIP_LOGS=0 QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d" QUEUEBASH_CLASS_SOURCE_DIR="$repo_root/classes"
source "$repo_root/queuebash.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"; _queue_init
fail(){ echo "[FAIL] $1" >&2; queue classes list >&2 || true; find "$QUEUEBASH_ROOT/classes" -maxdepth 4 -print -exec sh -c 'test -f "$1" && echo "### $1" && sed -n "1,120p" "$1"' _ {} \; >&2 || true; exit 1; }
pass(){ echo "[PASS] $1"; }
mkdir -p "$tmp/class_src"
cat > "$tmp/class_src/TEST.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_SHARED_ASSETS=""
CLASS_EXCLUSIVE_ASSETS=""
CLASS
queue classes refresh "$tmp/class_src" >/dev/null || fail "class refresh failed"
[[ -f "$QUEUEBASH_ROOT/classes/TEST.env" ]] || fail "TEST not installed"
queue classes validate TEST >/dev/null || fail "TEST invalid"
cat > "$tmp/class_src/TEST.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=0
CLASS_MAX_CONCURRENT=1
CLASS_SHARED_ASSETS="path:exists:/tmp"
CLASS_EXCLUSIVE_ASSETS="test:slot"
CLASS
queue classes refresh "$tmp/class_src" >/dev/null || fail "class refresh replacement failed"
queue classes backups TEST | grep -q 'TEST\..*\.env' || fail "TEST backup missing"
queue classes show TEST | grep -q 'CLASS_ALLOW_PARALLEL=0' || fail "TEST replacement not active"
queue classes rollback TEST >/dev/null || fail "class rollback failed"
queue classes show TEST | grep -q 'CLASS_ALLOW_PARALLEL=1' || fail "TEST rollback failed"
queue submit uses_test --class TEST -- bash -c 'echo test' >/dev/null
if queue classes delete TEST >/dev/null 2>&1; then fail "delete should refuse while pending job references TEST"; fi
mv "$QUEUEBASH_ROOT/pending"/*.job "$QUEUEBASH_ROOT/cancelled/"
queue classes delete TEST >/dev/null || fail "class delete failed"
[[ ! -f "$QUEUEBASH_ROOT/classes/TEST.env" ]] || fail "TEST still active"
queue classes archives TEST | grep -q 'TEST\..*\.env' || fail "archive missing"
queue classes undelete TEST >/dev/null || fail "undelete failed"
[[ -f "$QUEUEBASH_ROOT/classes/TEST.env" ]] || fail "TEST not restored"
out="$(queue classes explain TEST || true)"; grep -q 'CLASS EXPLAIN: TEST' <<< "$out" || fail "explain missing"
pass "class refresh and validate works"
pass "class rollback restores previous class"
pass "class delete archives only when unused"
pass "class undelete restores archived class"
echo
echo "bashqueues class manager lifecycle tests: OK"
