#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="${TMPDIR:-/tmp}/bq_global_smoke_$$"
GROOT="${TMPDIR:-/tmp}/bq_global_root_$$"
rm -rf "$ROOT" "$GROOT"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh
export QUEUEBASH_ROOT="$ROOT"
export QUEUEBASH_GLOBAL_ROOT="$GROOT"
queue version >/dev/null
mkdir -p "$ROOT/classes"
cat >"$ROOT/classes/GLOBAL_ONE.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
queue_class_global_exclusive_claim "github:publish"
CLASS
queue submit first --class GLOBAL_ONE -- bash -c 'sleep 0' >/dev/null
first_job="$(ls "$ROOT/pending"/*.job | head -1)"
first_id="$(basename "$first_job" .job)"
_queue_class_load_for_job "$first_job" >/dev/null
_queue_global_claims_acquire_for_job "$first_job" "$first_id"
queue global claims | grep -F 'github:publish' >/dev/null
queue global claim github:publish | grep -F "$first_id" >/dev/null
_queue_global_release_job_claims "$first_id" "$ROOT"
if queue global claims | grep -F "$first_id" >/dev/null; then
  echo 'global holder was not released' >&2
  exit 1
fi
rm -rf "$ROOT" "$GROOT"
echo '[PASS] functional global claim acquire/list/release smoke test passed'
