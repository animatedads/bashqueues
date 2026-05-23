#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_RUNNER=direct QUEUEBASH_GZIP_LOGS=0 QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d" QUEUEBASH_CLASS_SOURCE_DIR="$repo_root/classes"
source "$repo_root/queuebash.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"; _queue_init
fail(){ echo "[FAIL] $1" >&2; queue assets >&2 || true; exit 1; }
pass(){ echo "[PASS] $1"; }
[[ -f "$QUEUEBASH_ROOT/assets.d/format.sh" ]] || fail "format plugin not installed"
queue assets validate >/dev/null || fail "format plugin contract should validate"
queue assets | grep -q '^format:json' || fail "format:json missing"
queue assets | grep -q '^format:csv' || fail "format:csv missing"
json="$tmp/ok.json"; csv="$tmp/ok.csv"; badcsv="$tmp/bad.csv"
printf '{"ok": true}\n' > "$json"
printf 'a,b\n1,2\n3,4\n' > "$csv"
printf 'a,b\n1,2,3\n' > "$badcsv"
cat > "$QUEUEBASH_ROOT/classes/FORMAT_OK.env" <<CLASS
CLASS_ALLOW_PARALLEL=1
CLASS_SHARED_ASSETS="format:json:$json format:csv:$csv:strict_columns=1"
CLASS
queue submit format_ok --class FORMAT_OK -- bash -c 'echo format-ok' >/dev/null
job="$(grep -l '^JOB_NAME=format_ok$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
_queue_class_available "$job" || fail "format_ok should dispatch"
cat > "$QUEUEBASH_ROOT/classes/FORMAT_BLOCK.env" <<CLASS
CLASS_ALLOW_PARALLEL=1
CLASS_SHARED_ASSETS="format:csv:$badcsv:strict_columns=1"
CLASS
queue submit format_block --class FORMAT_BLOCK -- bash -c 'echo should-not-run' >/dev/null
bjob="$(grep -l '^JOB_NAME=format_block$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
if _queue_class_available "$bjob"; then fail "bad CSV should block dispatch"; fi
pass "format plugin publishes and validates contract"
pass "format json/csv checks dispatch"
pass "strict CSV check blocks malformed rows"
echo
echo "bashqueues format asset plugin tests: OK"
