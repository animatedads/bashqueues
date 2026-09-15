#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/root" QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh
_queue_init
id=launch_meta_pending
mkdir -p "$QUEUEBASH_ROOT/running"
cat > "$QUEUEBASH_ROOT/running/$id.job" <<JOB
JOB_ID=$id
JOB_NAME=launch_meta_pending
RUNNER_USED=direct
SUBMITTED_AT=$(date -Is)
COMMAND=( /bin/true )
JOB
queue health --fix >/tmp/qh.$$ || true
[[ -f "$QUEUEBASH_ROOT/running/$id.job" ]]
[[ ! -f "$QUEUEBASH_ROOT/interrupted/$id.job" ]]
