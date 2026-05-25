#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$ROOT/q"
export QUEUEBASH_SHARED_POLICY_ROOT="$ROOT/noetc"
source ./queuebash.sh
queue version >/dev/null
mkdir -p "$QUEUEBASH_ROOT/pol_block"
cat > "$QUEUEBASH_ROOT/pol_block/q1.job" <<'JOB'
JOB_NAME=pb
JOB_ID=q1
SUBMIT_USER=root
COMMAND=( echo hi )
JOB
queue reevaluate --all | grep -q 'Requeued q1 -> pending'
test -f "$QUEUEBASH_ROOT/pending/q1.job"
echo '[PASS] pol_block jobs can be reevaluated and requeued when policy now allows them'
