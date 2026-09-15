#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$(mktemp -d)"
trap 'kill "${spid:-}" >/dev/null 2>&1 || true; rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh
_queue_init >/dev/null 2>&1 || true

setsid sh -c 'sleep 30' >/dev/null 2>&1 &
spid=$!
sleep 0.2
pgid="$(ps -o pgid= -p "$spid" | tr -d '[:space:]')"
id="DUPDIRECT001"
mkdir -p "$root/running" "$root/interrupted" "$root/logs"
cat > "$root/running/$id.job" <<JOB
JOB_ID=$id
JOB_NAME=fc_camera_ffmpeg_build_retry_ed209e
PRIORITY=30
RUNNER_USED=direct
RUN_PID=$spid
RUN_PGID=$pgid
COMMAND=( sleep 30 )
JOB
cat > "$root/interrupted/$id.job" <<JOB
JOB_ID=$id
JOB_NAME=fc_camera_ffmpeg_build_retry_ed209e
PRIORITY=30
RUNNER_USED=direct
RUN_PID=$spid
RUN_PGID=$pgid
COMMAND=( sleep 30 )
INTERRUPTED_REASON=stale-running-detected-by-health
INTERRUPTED_FROM=running
JOB

out="$(queue health --fix 2>&1)"
printf '%s\n' "$out" | grep -q 'FIX duplicate state reconciled'
[[ -f "$root/running/$id.job" ]]
[[ ! -f "$root/interrupted/$id.job" ]]
find "$root/logs/queue-state-reconcile" -type f -name "$id.interrupted.duplicate.*.job" | grep -q .
kill "$spid" >/dev/null 2>&1 || true
wait "$spid" >/dev/null 2>&1 || true

echo "PASS stale direct duplicate reconcile smoke"
