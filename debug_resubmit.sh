#!/usr/bin/env bash
set -euo pipefail
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=0
export QUEUEBASH_PLUGIN_SOURCE_DIR="$PWD/assets.d"
export QUEUEBASH_CLASS_SOURCE_DIR="$PWD/classes"
source ./queuebash.sh
tmp="$(mktemp -d)"
export QUEUEBASH_ROOT="$tmp/q"
_queue_init
cat > "$QUEUEBASH_ROOT/classes/SHIFTING.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_DEFAULT_RUNNER=direct
CLASS_DEFAULT_TIMEOUT=10s
CLASS_DEFAULT_KILL_AFTER=1s
CLASS_DEFAULT_BILLING_CYCLES=1
CLASS_DEFAULT_BILLING_UNIT_SECONDS=60
CLASS_DEFAULT_BILLING_GRACE_SECONDS=5
queue_class_shared_asset path exists "/tmp"
CLASS
queue submit shifting --class SHIFTING -- bash -c 'exit 7'
qid="$(basename "$(grep -l '^JOB_NAME=shifting$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)" .job)"
queue run >/dev/null 2>&1 || true
cat > "$QUEUEBASH_ROOT/classes/SHIFTING.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_DEFAULT_RUNNER=direct
CLASS_DEFAULT_TIMEOUT=25s
CLASS_DEFAULT_KILL_AFTER=3s
CLASS_DEFAULT_CPU_LIMIT=25%
CLASS_DEFAULT_MEM_LIMIT=256M
CLASS_DEFAULT_BILLING_CYCLES=2
CLASS_DEFAULT_BILLING_UNIT_SECONDS=120
CLASS_DEFAULT_BILLING_GRACE_SECONDS=10
CLASS_DEFAULT_BILLING_POLICY=shortest-cap-wins
queue_class_shared_asset path exists "/tmp"
CLASS
echo "old qid=$qid"
queue resubmit "$qid"
echo "--- pending files ---"
ls -l "$QUEUEBASH_ROOT"/pending
for f in "$QUEUEBASH_ROOT"/pending/*.job; do
  echo "### $f"
  grep -E '^(JOB_ID|JOB_NAME|JOB_CLASS|TIMEOUT|KILL_AFTER|CPU_LIMIT|MEM_LIMIT|BILLING|CLASS_DEFAULTS|RUNNER|RUNNER_USED|EXIT_CODE|RESUBMITTED_FROM)=' "$f" || true
done
