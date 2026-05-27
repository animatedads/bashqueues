#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/request.json" <<'JSON'
{
  "schema": "queuebash.ai_advisory.request.v1",
  "operation": "ai.ask",
  "subject": "tester",
  "provider": "ollama",
  "model": "llama3",
  "question": "How do I submit a job?",
  "question_redacted": "How do I submit a job?",
  "context_allowed": "docs tests",
  "context_denied": "policies",
  "advisory_only": true
}
JSON

# Use an invalid local port so the helper fails immediately. The important
# behaviour is controlled JSON + concise stderr, not a Python traceback.
if bin/queue-ai-ask-ollama \
  --request-json "$tmp/request.json" \
  --output-json "$tmp/response.json" \
  --url http://127.0.0.1:9/api/generate \
  >"$tmp/stdout" 2>"$tmp/stderr"; then
  fail 'helper unexpectedly succeeded against closed local port'
fi

test -s "$tmp/response.json" || fail 'helper did not write error response JSON'
! grep -q 'Traceback' "$tmp/stderr" || fail 'helper leaked Python traceback'
grep -q 'ollama_provider_error:' "$tmp/stderr" || fail 'helper did not print concise provider error'
python3 - "$tmp/response.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema'] == 'queuebash.ai_advisory.response.v1'
assert j['provider'] == 'ollama'
assert j['decision'] == 'error'
assert j['advisory_only'] is True
assert j['response_length'] == 0
assert j['actions_suggested_authority'] == 'none'
assert 'ollama_' in j['reason'], j
PY

echo PASS
