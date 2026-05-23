#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_RUNNER=direct QUEUEBASH_GZIP_LOGS=0 QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d" QUEUEBASH_CLASS_SOURCE_DIR="$repo_root/classes"
source "$repo_root/queuebash.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"; _queue_init
fail(){ echo "[FAIL] $1" >&2; queue classes show GITHUB_PUBLISH >&2 || true; queue assets >&2 || true; find "$QUEUEBASH_ROOT" -maxdepth 5 -print >&2 || true; exit 1; }
pass(){ echo "[PASS] $1"; }
[[ -f "$QUEUEBASH_ROOT/classes/GITHUB_PUBLISH.env" ]] || fail "GITHUB_PUBLISH not installed"
queue classes validate GITHUB_PUBLISH >/dev/null || fail "GITHUB_PUBLISH did not validate"
queue classes show GITHUB_PUBLISH | grep -q 'net:http_status:https://github.com' || fail "missing github network check"
queue classes show GITHUB_PUBLISH | grep -q 'git:repo_exists' || fail "missing git repo check"
queue classes show GITHUB_PUBLISH | grep -q 'git:branch' || fail "missing git branch check"
queue classes show GITHUB_PUBLISH | grep -q 'CLASS_ALLOW_PARALLEL=0' || fail "should be serial"
out="$(queue classes explain GITHUB_PUBLISH || true)"; grep -q 'CLASS EXPLAIN: GITHUB_PUBLISH' <<< "$out" || fail "explain missing header"
queue classes expand | grep -q 'GITHUB_PUBLISH' || fail "expand missing GITHUB_PUBLISH"
pass "GITHUB_PUBLISH class installs"
pass "GITHUB_PUBLISH gates on github/network and git repo state"
pass "GITHUB_PUBLISH is visible through class manager"
echo
echo "bashqueues GitHub publish class tests: OK"
