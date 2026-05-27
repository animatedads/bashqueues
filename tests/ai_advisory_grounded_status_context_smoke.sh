#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$tmp/qroot"
export QUEUEBASH_AI_AUDIT_LOG="$tmp/ai.audit.jsonl"
source ./queuebash.sh

mkdir -p "$QUEUEBASH_ROOT/pending/p0999999990" "$QUEUEBASH_ROOT/logs"
qid="20260527_182226_1779906146865654_012711_16988"
cat > "$QUEUEBASH_ROOT/pending/p0999999990/$qid.job" <<JOB
JOB_ID=$qid
JOB_NAME=grounded_status_test
JOB_CLASS=DEFAULT
RUNNER=auto
SUBMITTED_AT=2026-05-27T18:22:26+00:00
COMMAND=( bash -c 'echo hello' )
JOB

# Without gates, job ids are detected but status is denied and no job context is collected.
out="$(queue ask --provider contract --context commands,assets,queue_status,job_status,job_metadata --json "Explain $qid")"
printf '%s\n' "$out" > "$tmp/denied.json"
python3 - "$tmp/denied.json" "$qid" <<'PY'
import json, sys
j=json.load(open(sys.argv[1]))
qid=sys.argv[2]
assert j['schema'] == 'queuebash.ai_advisory.request.v1'
assert qid in j['job_ids_detected']
assert 'commands' in j['context_allowed']
assert 'assets' in j['context_allowed']
assert 'queue_status' in j['context_denied']
assert 'job_status' in j['context_denied']
assert 'job_metadata' in j['context_denied']
assert j['job_context_collected'] == 0
assert j['tail_included'] is False
text=j['dynamic_context_text']
assert 'Installed queue command inventory' in text
assert 'Installed asset/facility inventory' in text
assert 'secaudit' in text
assert 'Job status/metadata context was requested but denied by policy.' in text
PY

export QUEUEBASH_AI_ALLOW_QUEUE_STATUS=1
export QUEUEBASH_AI_ALLOW_JOB_STATUS=1
export QUEUEBASH_AI_ALLOW_JOB_METADATA=1
out2="$(queue ask --provider contract --context commands,assets,queue_status,job_status,job_metadata --json "Explain $qid")"
printf '%s\n' "$out2" > "$tmp/allowed.json"
python3 - "$tmp/allowed.json" "$qid" <<'PY'
import json, sys
j=json.load(open(sys.argv[1]))
qid=sys.argv[2]
assert 'queue_status' in j['context_allowed']
assert 'job_status' in j['context_allowed']
assert 'job_metadata' in j['context_allowed']
assert qid in j['job_ids_detected']
assert j['job_context_collected'] == 1
assert j['tail_included'] is False
text=j['dynamic_context_text']
assert 'Redacted queue status context' in text
assert f'Redacted job status context for {qid}' in text
assert 'command_payload_redacted: true' in text
assert 'stdout_stderr_redacted: true' in text
assert 'metadata_included: true' in text
assert 'state: pending' in text
assert 'pending: 1' in text
PY

python3 - "$QUEUEBASH_AI_AUDIT_LOG" "$qid" <<'PY'
import json, sys
lines=[json.loads(x) for x in open(sys.argv[1]) if x.strip()]
assert len(lines) >= 2
last=lines[-1]
assert last['schema'] == 'queuebash.ai_advisory.audit.v1'
assert sys.argv[2] in last['job_ids_detected']
assert last['job_context_collected'] == 1
assert last['tail_included'] is False
assert last['redactions_applied'] is True
assert last['context_bundle_sha256']
PY

echo PASS
