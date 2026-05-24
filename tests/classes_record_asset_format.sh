#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_RUNNER=direct QUEUEBASH_GZIP_LOGS=0 QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d" QUEUEBASH_CLASS_SOURCE_DIR="$repo_root/classes"
source "$repo_root/queuebash.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"; _queue_init
fail(){ echo "[FAIL] $1" >&2; queue classes show RECORD >/dev/null 2>&1 && queue classes show RECORD >&2 || true; queue assets >&2 || true; find "$QUEUEBASH_ROOT" -maxdepth 5 -print >&2 || true; exit 1; }
pass(){ echo "[PASS] $1"; }
cat > "$QUEUEBASH_ROOT/assets.d/probe.sh" <<'PLUGIN'
queue_asset_facilities(){ echo "probe:target    parser-free record format probe"; }
queue_asset_check_probe_target(){
 local token="$1" target="$2"; shift 2 || true
 local want="" statuses="" note=""
 for p in "$@"; do case "$p" in want=*) want="${p#want=}" ;; statuses=*) statuses="${p#statuses=}" ;; note=*) note="${p#note=}" ;; esac; done
 [[ "$target" == "$want" ]] || { echo "target mismatch got=[$target] want=[$want]"; return 1; }
 [[ "$statuses" == "200,201,204,301,302,403" ]] || { echo "statuses mismatch [$statuses]"; return 1; }
 [[ "$note" == "a:b,c=d" ]] || { echo "note mismatch [$note]"; return 1; }
 return 0
}
PLUGIN
queue assets validate >/dev/null || fail "probe invalid"
cat > "$QUEUEBASH_ROOT/classes/RECORD.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
queue_class_exclusive_asset "record:slot"
queue_class_shared_asset probe target "https://github.com/a:b,c=d" \
  want="https://github.com/a:b,c=d" \
  statuses="200,201,204,301,302,403" \
  note="a:b,c=d"
CLASS
queue classes validate RECORD >/dev/null || fail "record class invalid"
queue submit record_job --class RECORD -- bash -c 'echo record-ok' >/dev/null
job="$(grep -l '^JOB_NAME=record_job$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
_queue_class_available "$job" || fail "record format should be available"
_queue_class_claim_job "$job" "$(basename "$job" .job)" || fail "record format should claim"
find "$QUEUEBASH_ROOT/claims/assets" -maxdepth 1 -type d -name '*record:slot*.claim' | grep -q . || fail "exclusive record claim missing"
pass "record format preserves arbitrary colons and commas"
pass "record format passes plugin preflight without token parsing"
pass "record format participates in asset claims"
echo
echo "bashqueues record class asset format tests: OK"
