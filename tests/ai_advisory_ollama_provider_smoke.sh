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

# Live providers are fail-closed unless policy explicitly enables them.
if queue ask --provider ollama --live --json "How should I run a safe job?" >"$tmp/blocked.out" 2>"$tmp/blocked.err"; then
  fail 'live ollama provider was allowed without QUEUEBASH_AI_LIVE_ENABLED=1'
fi
grep -q 'live_ai_provider_not_enabled' "$tmp/blocked.err" || fail 'missing live disabled reason'

cat > "$tmp/fake-ollama-helper" <<'FAKE'
#!/usr/bin/env python3
import argparse, json, pathlib
ap=argparse.ArgumentParser()
ap.add_argument('--request-json', required=True)
ap.add_argument('--output-json', required=True)
args=ap.parse_args()
req=json.load(open(args.request_json))
assert req['schema'] == 'queuebash.ai_advisory.request.v1'
assert req['operation'] == 'ai.ask'
assert req['provider'] == 'ollama'
assert req['advisory_only'] is True
assert 'tests' in req['context_allowed']
assert 'policies' in req['context_denied']
assert 'How should' in req['question']
out={
  'schema':'queuebash.ai_advisory.response.v1',
  'provider':'ollama',
  'model':req.get('model','llama3'),
  'decision':'answered',
  'answer_markdown':'Use queue submit with an appropriate class. This is advisory only.',
  'advisory_only':True,
  'actions_suggested_authority':'suggestion_only',
  'context_manifest':[],
  'context_bundle_sha256':'fake',
  'response_sha256':'fake',
  'response_length':65,
  'redactions_observed':True
}
pathlib.Path(args.output_json).write_text(json.dumps(out))
FAKE
chmod +x "$tmp/fake-ollama-helper"

export QUEUEBASH_AI_LIVE_ENABLED=1
export QUEUEBASH_AI_OLLAMA_HELPER="$tmp/fake-ollama-helper"
out="$(queue ask --provider ollama --model llama3 --context docs,tests,policies --live --json "How should I run a safe job?")"
printf '%s\n' "$out" > "$tmp/resp.json"
python3 -m json.tool "$tmp/resp.json" >/dev/null
python3 - "$tmp/resp.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema'] == 'queuebash.ai_advisory.response.v1'
assert j['provider'] == 'ollama'
assert j['decision'] == 'answered'
assert j['advisory_only'] is True
assert j['actions_suggested_authority'] == 'suggestion_only'
assert 'advisory only' in j['answer_markdown']
PY

python3 - "$QUEUEBASH_AI_AUDIT_LOG" <<'PY'
import json,sys
lines=[json.loads(x) for x in open(sys.argv[1]) if x.strip()]
assert len(lines) >= 2
assert any(x['result']=='blocked' and x.get('reason')=='live_ai_provider_not_enabled' for x in lines)
answered=[x for x in lines if x['provider']=='ollama' and x['result']=='answered']
assert answered, lines
last=answered[-1]
assert last['operation'] == 'ai.ask'
assert last['policy_decision'] == 'allow'
assert int(last['response_length']) > 0
assert 'tests' in last['context_allowed']
assert 'policies' in last['context_denied']
PY

echo PASS
