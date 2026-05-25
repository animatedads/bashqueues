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
JOB_NAME=hello
JOB_ID=q1
COMMAND=( echo hi )
JOB
queue backup create "$ROOT/backup.tar.gz" >/dev/null
queue backup restore "$ROOT/backup.tar.gz" --to "$ROOT/restore" --force >/dev/null
test -d "$ROOT/restore/pending"
test -f "$ROOT/restore/pending/q1.job"
echo '[PASS] queue backup and restore round-trip a filesystem queue snapshot'
