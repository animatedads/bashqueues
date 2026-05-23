#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_RUNNER=direct QUEUEBASH_GZIP_LOGS=0 QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d"
source "$repo_root/queuebash.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"; _queue_init
fail(){ echo "[FAIL] $1" >&2; queue assets >&2 || true; queue assets explain foo >&2 || true; exit 1; }
pass(){ echo "[PASS] $1"; }
plugins="$tmp/plugins"; mkdir -p "$plugins"
cat > "$plugins/foo.sh" <<'PLUGIN'
queue_asset_facilities(){ echo "foo:ready    Checks foo.ready exists"; }
queue_asset_check_foo_ready(){ local token="$1"; local target="$2"; shift 2 || true; [[ -f "$QUEUEBASH_ROOT/$target.ready" ]]; }
PLUGIN
queue assets refresh "$plugins" >/dev/null || fail "refresh failed"
[[ -f "$QUEUEBASH_ROOT/assets.d/foo.sh" ]] || fail "foo plugin not installed"
queue assets validate >/dev/null || fail "foo invalid"
queue assets | grep -q 'foo:ready' || fail "foo missing"
out="$(queue assets explain foo || true)"; grep -q 'ASSET EXPLAIN: foo' <<< "$out" || fail "explain header missing"
out="$(queue assets explain foo:ready || true)"; grep -q 'queue_asset_check_foo_ready' <<< "$out" || fail "explain function missing"
cat > "$QUEUEBASH_ROOT/classes/FOO.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_SHARED_ASSETS="foo:ready:gate"
CLASS
if queue assets delete foo >/dev/null 2>&1; then fail "delete should refuse while used"; fi
[[ -f "$QUEUEBASH_ROOT/assets.d/foo.sh" ]] || fail "foo removed despite refusal"
rm -f "$QUEUEBASH_ROOT/classes/FOO.env"
queue assets delete foo >/dev/null || fail "delete unused failed"
[[ ! -f "$QUEUEBASH_ROOT/assets.d/foo.sh" ]] || fail "foo still active"
queue assets archives foo | grep -q 'foo\..*\.sh' || fail "archive missing"
queue assets undelete foo >/dev/null || fail "undelete failed"
[[ -f "$QUEUEBASH_ROOT/assets.d/foo.sh" ]] || fail "foo not restored"
queue assets validate >/dev/null || fail "invalid after undelete"
cat > "$plugins/foo.sh" <<'PLUGIN'
queue_asset_facilities(){ echo "foo:ready    v2 check"; }
queue_asset_check_foo_ready(){ local token="$1"; local target="$2"; shift 2 || true; [[ -f "$QUEUEBASH_ROOT/$target.v2" ]]; }
PLUGIN
queue assets refresh "$plugins" >/dev/null || fail "refresh v2 failed"
queue assets backups foo | grep -q 'foo\..*\.sh' || fail "backup missing"
cat > "$QUEUEBASH_ROOT/classes/FOO2.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_SHARED_ASSETS="foo:ready:gate"
CLASS
queue submit foojob --class FOO2 -- bash -c 'echo foojob' >/dev/null
job="$(grep -l '^JOB_NAME=foojob$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
touch "$QUEUEBASH_ROOT/gate.v2"
_queue_class_available "$job" || fail "v2 plugin should dispatch"
pass "refresh installs and replaces plugins transactionally"
pass "delete archives only unused plugins"
pass "undelete restores archived plugin"
pass "explain reports plugin and facility details"
echo
echo "bashqueues asset refresh/delete/explain tests: OK"
