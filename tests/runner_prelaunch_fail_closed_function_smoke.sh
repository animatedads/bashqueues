#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
# shellcheck disable=SC1091
source ./queuebash.sh
_queue_systemd_user_service_supported(){ return 1; }
set +e
out="$(_queue_runner_for_job systemd '' '' '' 2>/dev/null)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "runner_prelaunch_fail_closed_function_smoke: expected systemd resolution failure" >&2; exit 1; }
[[ "$out" == "systemd-unavailable" ]] || { echo "runner_prelaunch_fail_closed_function_smoke: unexpected token: $out" >&2; exit 1; }
if _queue_runner_launchable_token "$out"; then
  echo "runner_prelaunch_fail_closed_function_smoke: unsafe token considered launchable" >&2
  exit 1
fi
_queue_runner_launchable_token direct
_queue_runner_launchable_token systemd
echo "runner_prelaunch_fail_closed_function_smoke: ok"
