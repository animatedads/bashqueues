#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_RUNNER=direct QUEUEBASH_GZIP_LOGS=0 QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d" QUEUEBASH_CLASS_SOURCE_DIR="$repo_root/classes"
source "$repo_root/queuebash.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"; _queue_init
fail(){ echo "[FAIL] $1" >&2; queue assets >&2 || true; exit 1; }
pass(){ echo "[PASS] $1"; }
cat > "$QUEUEBASH_ROOT/assets.d/probe.sh" <<'PLUGIN'
queue_asset_facilities(){ echo "probe:target    Checks parser preserves colon-bearing targets"; }
queue_asset_check_probe_target(){
 local token="$1" target="$2"; shift 2 || true
 local want="" mode=""
 for p in "$@"; do case "$p" in want=*) want="${p#want=}" ;; mode=*) mode="${p#mode=}" ;; esac; done
 [[ "$target" == "$want" ]] || { echo "target mismatch got=[$target] want=[$want]"; return 1; }
 [[ "$mode" == "ok" ]] || return 1
}
PLUGIN
queue assets validate >/dev/null || fail "probe plugin should validate"
cat > "$QUEUEBASH_ROOT/classes/PROBE.env" <<CLASS
CLASS_ALLOW_PARALLEL=1
CLASS_SHARED_ASSETS="probe:target:https://github.com:want=https://github.com:mode=ok probe:target:db.internal:5432:want=db.internal:5432:mode=ok"
CLASS
queue submit probe_ok --class PROBE -- bash -c 'echo probe-ok' >/dev/null
job="$(grep -l '^JOB_NAME=probe_ok$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
_queue_class_available "$job" || fail "colon-bearing targets should dispatch"
pass "asset parser preserves https:// targets"
pass "asset parser preserves host:port targets"
pass "asset parser preserves colon-bearing parameter values"
echo
echo "bashqueues colon target asset parser tests: OK"
