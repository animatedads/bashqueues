#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
root="$(mktemp -d "${TMPDIR:-/tmp}/queue-ask-cerebras-smoke.XXXXXX")"
trap 'rm -rf "$root"' EXIT

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$root/qroot"
source ./queuebash.sh
queue_ask_smoke_eval='export QUEUEBASH_ALLOW_NONINTERACTIVE=1; source ./queuebash.sh;'

timeout 30 bash -lc "${queue_ask_smoke_eval} queue ask provider explain cerebras --json" > "$root/cerebras-discovery.json"
python3 - "$root/cerebras-discovery.json" <<'PYJSON1'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ask_provider.discovery.v1'
assert j['provider']=='cerebras'
assert j['requires_network'] is True
assert j['live_supported'] is True
assert j['supports_json'] is True
PYJSON1

timeout 30 bash -lc "${queue_ask_smoke_eval} queue ask provider test cerebras --fixture --json" > "$root/cerebras-fixture.json"
python3 - "$root/cerebras-fixture.json" <<'PYJSON2'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ask_provider.fixture_test.v1'
assert j['provider']=='cerebras'
assert j['status']=='ok'
assert j['live_call_performed'] is False
PYJSON2

if timeout 30 bash -lc "${queue_ask_smoke_eval} queue ask --provider cerebras --live --json 'What is queue ask?'" > "$root/blocked.json" 2> "$root/blocked.err"; then
  echo 'FAIL: cerebras live path succeeded without QUEUEBASH_AI_LIVE_ENABLED' >&2
  exit 1
fi
grep -q 'live_ai_provider_not_enabled' "$root/blocked.err" || { echo 'FAIL: cerebras live block reason missing' >&2; cat "$root/blocked.err" >&2; exit 1; }

cat > "$root/request.json" <<'JSON'
{"schema":"queuebash.ai_advisory.request.v1","operation":"ai.ask","provider":"cerebras","model":"gpt-oss-120b","question":"hello","context_allowed":"docs","dynamic_context_text":"","advisory_only":true}
JSON
if QUEUEBASH_AI_CEREBRAS_ENDPOINT="http://127.0.0.1:9/v1/chat/completions" bin/queue-ai-ask-cerebras --request-json "$root/request.json" --output-json "$root/response.json" >/dev/null 2> "$root/helper.err"; then
  echo 'FAIL: cerebras helper succeeded without API key' >&2
  exit 1
fi
python3 - "$root/response.json" <<'PYJSON3'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ai_advisory.response.v1'
assert j['provider']=='cerebras'
assert j['status']=='error'
assert 'cerebras_api_key_missing' in j['reason']
assert j['live_call_performed'] is False
PYJSON3

echo 'PASS ask_cerebras_provider_smoke'
