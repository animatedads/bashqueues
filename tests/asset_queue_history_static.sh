#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source assets.d/queue.sh

facilities="$(queue_asset_facilities)"
hints="$(queue_asset_hints)"

for token in \
  queue:command_has_run \
  queue:command_has_not_run \
  queue:job_has_run \
  queue:job_has_not_run
 do
    grep -q "^${token}[[:space:]]" <<< "$facilities" || { echo "missing facility $token" >&2; exit 1; }
    grep -q "^${token}[[:space:]]" <<< "$hints" || { echo "missing hint $token" >&2; exit 1; }
    func="queue_asset_check_${token//:/_}"
    declare -F "$func" >/dev/null || { echo "missing check function $func" >&2; exit 1; }
 done

grep -q 'queue_class_shared_asset queue command_has_run "nightly_export.sh" match=substr time=24h' assets.d/queue.sh || {
    echo "queue history hints must include command_has_run example" >&2
    exit 1
}

grep -q 'Use `proc:not_running`' README.md || {
    echo "README must distinguish queue history checks from proc current-process checks" >&2
    exit 1
}

if grep -q 'assets.d/net_usage.sh' < <(find . -maxdepth 3 -type f); then
    echo "assets.d/net_usage.sh must remain removed" >&2
    exit 1
fi

echo "[PASS] queue history asset publishes facilities, hints, and check functions"
