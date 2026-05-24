#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

[[ ! -e "$repo_root/assets.d/net_usage.sh" ]] || fail "assets.d/net_usage.sh must not be restored"
bash -n "$repo_root/assets.d/net.sh" || fail "net.sh syntax"

source "$repo_root/assets.d/net.sh"
queue_asset_facilities | grep -q '^net:allowance' || fail "net:allowance not published by net.sh"
declare -F queue_asset_check_net_allowance >/dev/null || fail "queue_asset_check_net_allowance missing"

printf '1024\n' > /tmp/bashqueue_net_allowance_counter.ok
out="$(queue_asset_check_net_allowance charged counter_file=/tmp/bashqueue_net_allowance_counter.ok allowance_bytes=2K direction=rx_tx 2>&1)" || {
  echo "$out" >&2
  fail "net:allowance ok check failed"
}
echo "$out" | grep -q 'asset_check_ok: net:allowance' || fail "net:allowance ok output missing"

printf '4096\n' > /tmp/bashqueue_net_allowance_counter.bad
out="$(queue_asset_check_net_allowance charged counter_file=/tmp/bashqueue_net_allowance_counter.bad allowance_bytes=2K direction=rx_tx 2>&1)" && {
  echo "$out" >&2
  fail "net:allowance exceeded check unexpectedly passed"
}
echo "$out" | grep -q 'asset_check_blocked: net:allowance exceeded' || fail "net:allowance exceeded output missing"

grep -q 'queue_class_shared_asset net allowance' "$repo_root/docs/ASSETS.md" || fail "docs/ASSETS canonical net allowance example missing"
grep -q 'net:allowance' "$repo_root/README.md" || fail "README missing net:allowance"
grep -q 'net:allowance' "$repo_root/docs/CLASSES.md" || fail "CLASSES missing net:allowance"
grep -q 'net:allowance' "$repo_root/docs/QUEUEMGR.md" || fail "QUEUEMGR missing net:allowance"
grep -q '0.16.33' "$repo_root/CHANGELOG.md" || fail "CHANGELOG missing 0.16.33"

pass "net:allowance is canonical"
pass "assets.d/net_usage.sh remains removed"
pass "asset naming documentation updated"

echo
echo "bashqueues net allowance naming tests: OK"
