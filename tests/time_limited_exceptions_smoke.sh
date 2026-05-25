#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$ROOT/q"
source ./queuebash.sh
queue version >/dev/null
mkdir -p "$QUEUEBASH_ROOT/pending"
cat > "$QUEUEBASH_ROOT/pending/q1.job" <<'JOB'
JOB_NAME=test
JOB_ID=q1
COMMAND=( echo hi )
JOB
queue exception add q1 time:window --reason ok --expires +1d >/dev/null
queue exception list q1 | grep -q '+1d'
echo '[PASS] time-limited exception overlays list expiry metadata'
