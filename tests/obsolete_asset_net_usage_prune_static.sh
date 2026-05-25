#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "[FAIL] $*" >&2; exit 1; }
pass(){ echo "[PASS] $*"; }

repo_root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$repo_root"

[[ ! -e assets.d/net_usage.sh ]] || fail "assets.d/net_usage.sh must not be restored"

grep -q '_queue_obsolete_asset_plugins' queuebash.sh || fail "obsolete asset plugin prune helper missing"
grep -q 'net_usage' queuebash.sh || fail "net_usage obsolete asset marker missing"
grep -q '_queue_prune_obsolete_asset_plugins' queuebash.sh || fail "obsolete asset prune call missing"
grep -q 'kind == "asset" and name == "net_usage"' queuemgr_panel.py || fail "panel should hide stale asset:net_usage defensively"

grep -q 'elif \[\[ -f "\$disabled" \]\]' queuebash.sh || fail "module explain should use explicit active-then-disabled path selection"

pass "stale asset-side net_usage is pruned/hidden and module explain reads active module first"

# Functional smoke: a stale selected-root asset copy is archived and hidden from module list.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.queuebash/assets.d" "$tmp/.queuebash/caps.d"
printf '%s\n' '# stale removed asset plugin' > "$tmp/.queuebash/assets.d/net_usage.sh"
QUEUEBASH_ROOT="$tmp/.queuebash" QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc 'source ./queuebash.sh; queue modules list' > "$tmp/modules.out" 2> "$tmp/modules.err"
if grep -q $'asset\tnet_usage\t' "$tmp/modules.out"; then
  cat "$tmp/modules.out" >&2
  fail "stale asset-side net_usage should not appear in modules list"
fi
[[ ! -e "$tmp/.queuebash/assets.d/net_usage.sh" ]] || fail "stale asset-side net_usage should be archived"
ls "$tmp/.queuebash/assets.d/.obsolete"/net_usage.*.sh >/dev/null 2>&1 || fail "obsolete net_usage archive not created"

pass "functional stale asset-side net_usage prune smoke test passed"
