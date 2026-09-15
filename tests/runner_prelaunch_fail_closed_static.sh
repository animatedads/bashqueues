#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
fail(){ echo "runner_prelaunch_fail_closed_static: $*" >&2; exit 1; }
grep -q '_queue_runner_launchable_token' queuebash.sh || fail 'launchable token helper missing'
grep -q 'runner_resolution_rc=0' queuebash.sh || fail 'runner resolution rc capture missing'
grep -q 'RUNNER_PRELAUNCH_BLOCKED' queuebash.sh || fail 'prelaunch blocked marker missing'
grep -q 'reason=runner_unavailable_or_unsafe' queuebash.sh || fail 'clear prelaunch reason missing'
grep -q 'printf '\''RUNNER_PRELAUNCH_REQUESTED=%q' queuebash.sh || fail 'requested runner evidence missing'
grep -q 'printf '\''RUNNER_PRELAUNCH_RC=%q' queuebash.sh || fail 'runner rc evidence missing'
echo "runner_prelaunch_fail_closed_static: ok"
