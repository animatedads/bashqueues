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

fail(){
  echo "[FAIL] $1" >&2
  echo "--- out ---" >&2; cat /tmp/refresh.out 2>/dev/null >&2 || true
  echo "--- err ---" >&2; cat /tmp/refresh.err 2>/dev/null >&2 || true
  find "$QUEUEBASH_ROOT" -maxdepth 4 -type f -print -exec sh -c 'echo "### $1"; sed -n "1,120p" "$1"' _ {} \; >&2 || true
  exit 1
}
pass(){ echo "[PASS] $1"; }

adir="$tmp/assets.d"
mkdir -p "$adir"
cat > "$adir/demo.sh" <<'PLUGIN'
queue_asset_facilities() { echo "demo:ok Demo asset"; }
queue_asset_check_demo_ok() { echo "asset_check_ok: demo:ok"; }
PLUGIN

queue assets refresh "$adir" >/tmp/refresh.out 2>/tmp/refresh.err || fail "queue assets refresh failed"
[[ -f "$QUEUEBASH_ROOT/assets.d/demo.sh" ]] || fail "asset plugin not installed by grouped command"
if grep -q 'queue classes refresh' /tmp/refresh.err /tmp/refresh.out 2>/dev/null; then
  fail "asset refresh routed through class refresh"
fi
queue assets validate >/dev/null || fail "refreshed asset failed validation"
queue assets | grep -q 'demo:ok' || fail "refreshed asset facility not listed"

rm -f "$QUEUEBASH_ROOT/assets.d/demo.sh"
queue asset-refresh "$adir" >/tmp/refresh.out 2>/tmp/refresh.err || fail "queue asset-refresh failed"
[[ -f "$QUEUEBASH_ROOT/assets.d/demo.sh" ]] || fail "asset plugin not installed by direct alias"
if grep -q 'queue classes refresh' /tmp/refresh.err /tmp/refresh.out 2>/dev/null; then
  fail "direct asset-refresh routed through class refresh"
fi

cdir="$tmp/classes"
mkdir -p "$cdir"
cat > "$cdir/DEMOCLASS.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
queue_class_shared_asset demo ok "x"
CLASS
queue class-refresh "$cdir" >/tmp/refresh.out 2>/tmp/refresh.err || fail "queue class-refresh failed"
[[ -f "$QUEUEBASH_ROOT/classes/DEMOCLASS.env" ]] || fail "class not installed by direct class-refresh"

pass "queue assets refresh routes to asset plugin refresh"
pass "queue asset-refresh direct alias routes to asset plugin refresh"
pass "queue class-refresh direct alias still loads class definitions"

echo
echo "bashqueues refresh dispatch hardening tests: OK"
