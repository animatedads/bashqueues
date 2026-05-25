#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_RUNNER=direct QUEUEBASH_GZIP_LOGS=0 QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d"
source "$repo_root/queuebash.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"; _queue_init
fail(){ echo "[FAIL] $1" >&2; find "$QUEUEBASH_ROOT/classes" -maxdepth 1 -type f -print -exec cat {} \; >&2 || true; exit 1; }
pass(){ echo "[PASS] $1"; }
[[ -f "$QUEUEBASH_ROOT/classes/DEFAULT.env" ]] || fail "DEFAULT.env missing"
queue classes show default >/dev/null || fail "lowercase default did not resolve"
queue classes show DEFAULT >/dev/null || fail "uppercase DEFAULT did not resolve"
pass "class lookup resolves default case-insensitively"
echo
echo "bashqueues default class case lookup tests: OK"
