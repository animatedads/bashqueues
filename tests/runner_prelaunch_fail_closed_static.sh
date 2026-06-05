#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q 'RUNNER_PRELAUNCH_BLOCKED:' queuebash.sh || { echo "missing RUNNER_PRELAUNCH_BLOCKED log marker" >&2; exit 1; }
grep -q 'runner_unavailable_or_unsafe' queuebash.sh || { echo "missing runner_unavailable_or_unsafe reason" >&2; exit 1; }
grep -q 'case "$runner_used" in' queuebash.sh || { echo "missing runner_used validation case" >&2; exit 1; }
grep -q 'direct|systemd' queuebash.sh || { echo "missing direct/systemd allow-list" >&2; exit 1; }

echo "PASS runner_prelaunch_fail_closed_static"
