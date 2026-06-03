#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT

# shellcheck disable=SC1091
source ./queuebash.sh >/dev/null 2>&1
_queue_init

assert_json() {
  local label="$1" data="$2"
  printf '%s\n' "$data" | python3 -S -m json.tool >/dev/null || {
    echo "invalid JSON: $label" >&2
    printf '%s\n' "$data" >&2
    return 1
  }
}

qid="WAVE3JSON0001"
mkdir -p "$QUEUEBASH_ROOT/done" "$QUEUEBASH_ROOT/logs"
cat > "$QUEUEBASH_ROOT/done/$qid.job" <<JOB
JOB_ID="$qid"
JOB_NAME="wave3_json_job"
PRIORITY=10
COMMAND=(bash -c 'echo wave3-json-tail')
SUBMITTED_AT="2026-01-01T00:00:00+00:00"
RUN_STARTED_AT="2026-01-01T00:00:01+00:00"
EXEC_FINISHED_AT="2026-01-01T00:00:02+00:00"
EXIT_CODE=0
JOB_CLASS="DEFAULT"
LOG_PATH="$QUEUEBASH_ROOT/logs/$qid.log"
JOB
printf 'line one\nwave3-json-tail\n' > "$QUEUEBASH_ROOT/logs/$qid.log"

show_json="$(queue show "$qid" --json)"
assert_json 'queue show --json' "$show_json"
printf '%s\n' "$show_json" | grep -F '"schema":"queuebash.show.v1"' >/dev/null
printf '%s\n' "$show_json" | grep -F 'wave3_json_job' >/dev/null

history_json="$(queue history "$qid" --json)"
assert_json 'queue history --json' "$history_json"
printf '%s\n' "$history_json" | grep -F '"schema":"queuebash.history.v1"' >/dev/null

tail_json="$(queue tail "$qid" --json --no-follow --tail 20 || true)"
assert_json 'queue tail --json --no-follow' "$tail_json"
printf '%s\n' "$tail_json" | grep -F '"schema":"queuebash.tail.v1"' >/dev/null
printf '%s\n' "$tail_json" | grep -F 'wave3-json-tail' >/dev/null

if queue tail "$qid" --json >/tmp/qb_tail_follow_json.out 2>/tmp/qb_tail_follow_json.err; then
  echo 'queue tail --json unexpectedly allowed follow mode' >&2
  exit 1
fi
assert_json 'queue tail --json follow refusal' "$(cat /tmp/qb_tail_follow_json.out)"
grep -F 'json_follow_not_supported' /tmp/qb_tail_follow_json.out >/dev/null

echo "queue command JSON wave 3 smoke checks passed"
