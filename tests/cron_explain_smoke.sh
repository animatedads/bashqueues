#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/spool" "$tmp/system" "$tmp/state" "$tmp/root"
cat > "$tmp/spool/testu" <<'CRON'
# queuebash test
*/2 * * * * echo test
15 14 * * * echo "at 14:15"
@daily /bin/true
@reboot /ignored
CRON
cat > "$tmp/spool/hc3" <<'CRON'
5 * * * * echo hc3
CRON

out="$(QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_ROOT="$tmp/root" QUEUEBASH_CRON_SPOOL_DIR="$tmp/spool" QUEUEBASH_CRON_SYSTEM_DIR="$tmp/system" QUEUEBASH_CRON_STATE_DIR="$tmp/state" bash -lc 'source ./queuebash.sh; queue cron explain testu')"
[[ "$out" == *"meaning:  every 2 minutes"* ]]
[[ "$out" == *"command:  echo test"* ]]
[[ "$out" == *"class:    cron_3dfa21b83bfa"* ]]
[[ "$out" == *"unsupported macro @reboot"* ]]

list_out="$(QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_ROOT="$tmp/root" QUEUEBASH_SELECTED_USER=testu QUEUEBASH_CRON_SPOOL_DIR="$tmp/spool" QUEUEBASH_CRON_SYSTEM_DIR="$tmp/system" QUEUEBASH_CRON_STATE_DIR="$tmp/state" bash -lc 'source ./queuebash.sh; queue cron list')"
[[ "$list_out" == *"testu  $tmp/spool/testu"* ]]
[[ "$list_out" != *"hc3  $tmp/spool/hc3"* ]]

echo "[PASS] cron explain renders human-readable cron entries and selected-user cron list is scoped"
