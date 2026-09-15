#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
export QUEUEBASH_ROOT="$ROOT"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
# shellcheck source=/dev/null
source "$SCRIPT_DIR/queuebash.sh"

qid="wait_reeval_$$"
mkdir -p "$ROOT/waiting/p0999999990"
cat > "$ROOT/waiting/p0999999990/$qid.job" <<JOB
JOB_ID='$qid'
JOB_NAME='waiting-reevaluate-demo'
JOB_CLASS='DEFAULT'
PRIORITY='10'
SUBMITTED_AT='2026-06-05T21:00:00+01:00'
PWD_AT_SUBMIT='$PWD'
WAIT_REASON='manual_recheck'
WAIT_DETAIL='waiting for explicit reevaluate smoke'
WAIT_LAST_PREFLIGHT='2026-06-05T21:14:03+01:00'
WAIT_NEXT_CHECK='2026-06-05T21:15:03+01:00'
WAIT_OPERATOR_ACTION='no_action_required'
COMMAND=( bash -lc 'echo reeval' )
JOB

json="$(queue reevaluate "$qid" --json)"
printf '%s\n' "$json" | python3 -m json.tool >/dev/null
printf '%s\n' "$json" | grep -q '"ok":true'
printf '%s\n' "$json" | grep -q '"command":"reevaluate"'
printf '%s\n' "$json" | grep -q '"from_state":"waiting"'
printf '%s\n' "$json" | grep -q '"to_state":"pending"'
printf '%s\n' "$json" | grep -q '"action":"requeued"'
[[ -f "$ROOT/pending/p0999999990/$qid.job" ]]
[[ ! -e "$ROOT/waiting/p0999999990/$qid.job" ]]

missing="$(queue reevaluate missing-wait --json || true)"
printf '%s\n' "$missing" | python3 -m json.tool >/dev/null
printf '%s\n' "$missing" | grep -q '"ok":false'
printf '%s\n' "$missing" | grep -q 'no pol_blocked or waiting jobs matched'
