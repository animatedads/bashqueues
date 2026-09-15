#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"; kill "$pid" 2>/dev/null || true' EXIT
export QUEUEBASH_ROOT="$tmp/root" QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh
_queue_init
sleep 30 & pid=$!
pgid="$(ps -o pgid= -p "$pid" | tr -d ' ')"
id=dup_pol
mkdir -p "$QUEUEBASH_ROOT/running" "$QUEUEBASH_ROOT/pol_blocked"
cat > "$QUEUEBASH_ROOT/running/$id.job" <<JOB
JOB_ID=$id
JOB_NAME=dup_pol
RUNNER_USED=direct
RUN_PID=$pid
RUN_PGID=$pgid
RUN_STARTED_AT=$(date -Is)
COMMAND=( sleep 30 )
JOB
cat > "$QUEUEBASH_ROOT/pol_blocked/$id.job" <<JOB
JOB_ID=$id
JOB_NAME=dup_pol
POLICY_BLOCKED_REASON='job file not found'
JOB
out="$(queue health --fix || true)"
printf '%s\n' "$out" | grep -q 'duplicate state reconciled'
[[ -f "$QUEUEBASH_ROOT/running/$id.job" ]]
[[ ! -f "$QUEUEBASH_ROOT/pol_blocked/$id.job" ]]
find "$QUEUEBASH_ROOT/logs/queue-state-reconcile" -type f -name 'dup_pol.pol_blocked.duplicate.*.job' | grep -q .
