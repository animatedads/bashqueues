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

out="$(queue ask --provider watson --context docs,commands,classes,queue_status --json "How do I run a GDPR-safe overnight job?")"
printf '%s\n' "$out" > "$tmp/request.json"
python3 -m json.tool "$tmp/request.json" >/dev/null
python3 - "$tmp/request.json" <<'PY'
import json, sys
j=json.load(open(sys.argv[1]))
assert j['schema'] == 'queuebash.ai_advisory.request.v1'
assert j['operation'] == 'ai.ask'
assert j['provider'] == 'watson'
assert j['advisory_only'] is True
assert j['provider_execution'] == 'not_implemented_contract_only'
assert 'docs' in j['context_allowed']
assert 'commands' in j['context_allowed']
assert 'classes' in j['context_allowed']
assert 'queue_status' in j['context_denied']
assert j['question_sha256']
assert j['context_bundle_sha256']
PY

test -s "$QUEUEBASH_AI_AUDIT_LOG" || fail 'audit log not written'
python3 - "$QUEUEBASH_AI_AUDIT_LOG" <<'PY'
import json, sys
lines=open(sys.argv[1]).read().strip().splitlines()
assert len(lines) == 1
j=json.loads(lines[0])
assert j['schema'] == 'queuebash.ai_advisory.audit.v1'
assert j['operation'] == 'ai.ask'
assert j['provider'] == 'watson'
assert j['policy_decision'] == 'allow'
assert j['result'] == 'handoff'
assert j['redactions_applied'] is True
assert j['response_length'] == 0
assert 'queue_status' in j['context_denied']
assert 'How do I run' in j['question_redacted']
PY

export QUEUEBASH_AI_ALLOW_QUEUE_STATUS=1
out2="$(queue ask --provider watson --context queue_status --json "Can I see why jobs are pending?")"
printf '%s\n' "$out2" > "$tmp/request2.json"
python3 - "$tmp/request2.json" <<'PY'
import json, sys
j=json.load(open(sys.argv[1]))
assert 'queue_status' in j['context_allowed']
assert 'queue_status' not in j['context_denied']
PY

echo PASS
