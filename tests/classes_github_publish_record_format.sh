#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_RUNNER=direct QUEUEBASH_GZIP_LOGS=0 QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d" QUEUEBASH_CLASS_SOURCE_DIR="$repo_root/classes"
source "$repo_root/queuebash.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"; _queue_init
fail(){ echo "[FAIL] $1" >&2; queue classes show GITHUB_PUBLISH >&2 || true; exit 1; }
pass(){ echo "[PASS] $1"; }
queue classes validate GITHUB_PUBLISH >/dev/null || fail "GITHUB_PUBLISH invalid"
out="$(queue classes show GITHUB_PUBLISH)"
grep -q 'queue_class_shared_asset net http_status "https://github.com"' <<< "$out" || fail "github class not using record http_status"
grep -q 'accept_status="200,201,204,301,302,304,307,308,403"' <<< "$out" || fail "github class missing comma status record param"
grep -q 'queue_class_shared_asset git branch' <<< "$out" || fail "github class missing record git branch"
pass "GITHUB_PUBLISH uses delimiter-safe class records"
echo
echo "bashqueues GitHub publish record class tests: OK"
