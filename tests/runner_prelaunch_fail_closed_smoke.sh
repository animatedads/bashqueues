#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

root="$(mktemp -d)"
worker_out="/tmp/bq_runner_prelaunch_worker.$$"
trap 'rm -rf "$root" "$worker_out"' EXIT
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

queue submit prelaunch-systemd --runner systemd -- sh -c 'echo SHOULD_NOT_RUN; exit 0' >/dev/null
queue run --workers 1 >"$worker_out" 2>&1 || true

failed_job="$(find "$root/failed" -maxdepth 1 -name '*.job' -type f | head -1 || true)"
if [[ -z "$failed_job" ]]; then
  echo "expected failed job after unavailable explicit systemd request" >&2
  cat "$worker_out" >&2 || true
  exit 1
fi

job_id="$(basename "$failed_job" .job)"
log="$root/logs/$job_id.log"
if [[ -f "$log.gz" ]]; then
  log_text="$(gzip -cd "$log.gz")"
elif [[ -f "$log" ]]; then
  log_text="$(cat "$log")"
else
  echo "missing job log for $job_id" >&2
  find "$root/logs" -maxdepth 1 -type f -print >&2 || true
  exit 1
fi

grep -q '^RUNNER_USED=systemd-' "$failed_job" || { echo "missing systemd-* RUNNER_USED in failed job" >&2; cat "$failed_job" >&2; exit 1; }
printf '%s
' "$log_text" | grep -q 'RUNNER_PRELAUNCH_BLOCKED:' || { echo "missing prelaunch blocked log" >&2; printf '%s
' "$log_text" >&2; exit 1; }
printf '%s
' "$log_text" | grep -q 'runner_unavailable_or_unsafe' || { echo "missing runner unavailable reason" >&2; printf '%s
' "$log_text" >&2; exit 1; }
if printf '%s
' "$log_text" | grep -q '^launch_argv:'; then
  echo "payload launch argv emitted despite prelaunch block" >&2
  printf '%s
' "$log_text" >&2
  exit 1
fi

echo "PASS runner_prelaunch_fail_closed_smoke"
