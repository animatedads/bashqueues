#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$(mktemp -d "${TMPDIR:-/tmp}/queue-ask-groq-smoke.XXXXXX")"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root/qroot"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1

queue_ask_smoke_eval='source ./queuebash.sh; _queue_install_bundled_classes(){ :; }; _queue_install_bundled_env_profiles(){ :; }; _queue_install_bundled_asset_plugins(){ :; }; _queue_install_bundled_cap_plugins(){ :; }; _queue_install_bundled_reporter_plugins(){ :; }; _queue_install_bundled_policies(){ :; }; '

timeout 30 bash -lc "${queue_ask_smoke_eval} queue ask provider explain groq --json" > "$root/groq-discovery.json"
python3 - "$root/groq-discovery.json" <<'PYJSON1'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ask_provider.discovery.v1'
assert j['provider']=='groq'
assert j['requires_network'] is True
assert j['supports_json'] is True
assert j['live_supported'] is True
PYJSON1

timeout 30 bash -lc "${queue_ask_smoke_eval} queue ask provider test groq --fixture --json" > "$root/groq-fixture.json"
python3 - "$root/groq-fixture.json" <<'PYJSON2'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ask_provider.fixture_test.v1'
assert j['provider']=='groq'
assert j['status']=='ok'
assert j['live_call_performed'] is False
PYJSON2

if timeout 30 bash -lc "${queue_ask_smoke_eval} queue ask --provider groq --live --json 'What is queue ask?'" > "$root/blocked.json" 2> "$root/blocked.err"; then
  echo 'FAIL: groq live path succeeded without QUEUEBASH_AI_LIVE_ENABLED' >&2
  exit 1
fi
grep -q 'live_ai_provider_not_enabled' "$root/blocked.err"

cat > "$root/request.json" <<'JSONREQ'
{"schema":"queuebash.ai_advisory.request.v1","operation":"ai.ask","provider":"groq","model":"llama-3.3-70b-versatile","question":"hello","context_allowed":"docs","dynamic_context_text":"","advisory_only":true}
JSONREQ
if QUEUEBASH_AI_GROQ_ENDPOINT="http://127.0.0.1:9/openai/v1/chat/completions" bin/queue-ai-ask-groq --request-json "$root/request.json" --output-json "$root/response.json" >/dev/null 2> "$root/helper.err"; then
  echo 'FAIL: groq helper succeeded without API key' >&2
  exit 1
fi
python3 - "$root/response.json" <<'PYJSON3'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ai_advisory.response.v1'
assert j['provider']=='groq'
assert j['status']=='error'
assert j['live_call_performed'] is False
assert j['advisory_only'] is True
assert 'groq_api_key_missing' in j['reason']
PYJSON3

echo PASS
