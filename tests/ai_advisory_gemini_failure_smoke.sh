#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL: $*" >&2; exit 1; }
cd "$(dirname "$0")/.."

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d /tmp/queuebash-gemini-smoke.XXXXXX)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
source ./queuebash.sh

set +e
out=$(QUEUEBASH_AI_LIVE_ENABLED=1 QUEUEBASH_AI_GEMINI_API_KEY= queue ask --provider gemini --live --json "How do I submit a job?" 2>&1)
rc=$?
set -e
[[ "$rc" -ne 0 ]] || fail 'Gemini without key unexpectedly succeeded'
[[ "$out" == *'gemini_api_key_missing'* ]] || fail "missing-key reason not surfaced: $out"
[[ "$out" != *'Traceback'* ]] || fail 'Python traceback leaked on missing key'

log="$QUEUEBASH_ROOT/logs/ai-advisory.audit.jsonl"
[[ -s "$log" ]] || fail 'AI advisory audit log missing'
grep -q 'gemini_api_key_missing' "$log" || fail 'missing-key failure not audited'

# Direct helper path with a local fake endpoint should fail cleanly and write normalized JSON.
tmp=$(mktemp -d /tmp/queuebash-gemini-helper.XXXXXX)
cat > "$tmp/request.json" <<'JSON'
{
  "schema": "queuebash.ai_advisory.request.v1",
  "operation": "ai.ask",
  "provider": "gemini",
  "model": "gemini-test",
  "question": "How do I submit a job?",
  "context_allowed": "docs tests",
  "advisory_only": true
}
JSON
set +e
QUEUEBASH_AI_GEMINI_API_KEY='not-a-real-key' QUEUEBASH_AI_GEMINI_ENDPOINT='http://127.0.0.1:9/v1beta' \
  bin/queue-ai-ask-gemini --request-json "$tmp/request.json" --output-json "$tmp/response.json" >"$tmp/stdout" 2>"$tmp/stderr"
hrc=$?
set -e
[[ "$hrc" -ne 0 ]] || fail 'fake endpoint unexpectedly succeeded'
[[ -s "$tmp/response.json" ]] || fail 'helper did not write normalized failure JSON'
[[ "$(cat "$tmp/stderr")" != *'Traceback'* ]] || fail 'helper leaked traceback on unreachable endpoint'
python3 - "$tmp/response.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema'] == 'queuebash.ai_advisory.response.v1'
assert j['provider'] == 'gemini'
assert j['decision'] == 'error'
assert j['advisory_only'] is True
assert 'not-a-real-key' not in json.dumps(j)
PY
rm -rf "$tmp"

echo PASS
