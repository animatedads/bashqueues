#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

grep -q 'QUEUEBASH_VERSION="0.17.15"' queuebash.sh || fail "version not 0.17.15"
grep -q 'backup_dir="$cap_dir/.backup"' queuebash.sh || fail "cap refresh does not set explicit backup_dir"
grep -q 'mkdir -p "$cap_dir" "$backup_dir"' queuebash.sh || fail "cap refresh does not create caps.d and .backup"
grep -q 'cannot create cap directory or backup directory' queuebash.sh || fail "cap refresh lacks mkdir failure diagnostic"
grep -q 'failed to replace cap plugin' queuebash.sh || fail "cap refresh does not report failed replacement"

# Functional smoke: refresh into a clean queue root must create caps.d/.backup.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$tmp/q"
source "$repo_root/queuebash.sh"
queue caps refresh "$repo_root/caps.d" >/tmp/caps_refresh.out
[[ -d "$QUEUEBASH_ROOT/caps.d/.backup" ]] || fail "caps refresh did not create caps.d/.backup"
[[ -f "$QUEUEBASH_ROOT/caps.d/billing.sh" ]] || fail "billing cap was not refreshed"
[[ -f "$QUEUEBASH_ROOT/caps.d/net_usage.sh" ]] || fail "net_usage cap was not refreshed"

pass "caps refresh creates backup directory and handles failures safely"
