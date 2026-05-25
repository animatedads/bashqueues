#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source assets.d/proc.sh

facilities="$(queue_asset_facilities)"
hints="$(queue_asset_hints)"

for token in \
  proc:running \
  proc:not_running \
  proc:user_running \
  proc:pid_file \
  proc:max_instances \
  proc:cpu_user \
  proc:mem_user
 do
    grep -q "^${token}[[:space:]]" <<< "$facilities" || { echo "missing facility $token" >&2; exit 1; }
    grep -q "^${token}[[:space:]]" <<< "$hints" || { echo "missing hint $token" >&2; exit 1; }
    func="queue_asset_check_${token//:/_}"
    declare -F "$func" >/dev/null || { echo "missing check function $func" >&2; exit 1; }
 done

if grep -q 'assets.d/net_usage.sh' < <(find . -maxdepth 3 -type f); then
    echo "assets.d/net_usage.sh must remain removed" >&2
    exit 1
fi

echo "[PASS] proc asset publishes facilities, hints, and check functions"
