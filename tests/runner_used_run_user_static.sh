#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# The actual worker launch decision must pass RUN_USER into _queue_runner_for_job.
if ! grep -F 'runner_used="$(_queue_runner_for_job "${RUNNER:-${QUEUEBASH_RUNNER:-auto}}" "${CPU_LIMIT:-}" "${MEM_LIMIT:-}" "${RUN_USER:-}")" || runner_resolution_rc="$?";' queuebash.sh >/dev/null; then
  echo "runner_used launch decision does not include RUN_USER" >&2
  exit 1
fi
if grep -F 'runner_used="$(_queue_runner_for_job "${RUNNER:-${QUEUEBASH_RUNNER:-auto}}" "${CPU_LIMIT:-}" "${MEM_LIMIT:-}")"' queuebash.sh >/dev/null; then
  echo "stale three-argument runner_used launch decision remains" >&2
  exit 1
fi
if ! grep -F '_queue_build_payload_command "${CPU_LIMIT:-}" "${MEM_LIMIT:-}" "${PWD_AT_SUBMIT:-$PWD}" "$runner_used" "${effective_timeout:-}" "${KILL_AFTER:-}" "${SANDBOX_LEVEL:-}" "${RUN_USER:-}"' queuebash.sh >/dev/null; then
  echo "payload builder does not receive RUN_USER" >&2
  exit 1
fi
echo "PASS runner_used_run_user_static"
