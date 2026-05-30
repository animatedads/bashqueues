#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$(mktemp -d "${TMPDIR:-/tmp}/queue-ask-openai-smoke.XXXXXX")"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root/qroot"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1

queue_ask_smoke_eval='source ./queuebash.sh; _queue_install_bundled_classes(){ :; }; _queue_install_bundled_env_profiles(){ :; }; _queue_install_bundled_asset_plugins(){ :; }; _queue_install_bundled_cap_plugins(){ :; }; _queue_install_bundled_reporter_plugins(){ :; }; _queue_install_bundled_policies(){ :; }; '

timeout 30 bash -lc "${queue_ask_smoke_eval} queue ask provider explain openai --json" > "$root/openai-discovery.json"
python3 - "$root/openai-discovery.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ask_provider.discovery.v1'
assert j['provider']=='openai'
assert j['requires_network'] is True
assert j['supports_json'] is True
assert j['live_supported'] is True
PY

timeout 30 bash -lc "${queue_ask_smoke_eval} queue ask provider test openai --fixture --json" > "$root/openai-fixture.json"
python3 - "$root/openai-fixture.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ask_provider.fixture_test.v1'
assert j['provider']=='openai'
assert j['status']=='ok'
assert j['live_call_performed'] is False
PY

# Live OpenAI path remains gated by QUEUEBASH_AI_LIVE_ENABLED by default.
if timeout 30 bash -lc "${queue_ask_smoke_eval} queue ask --provider openai --live --json 'What is queue ask?'" > "$root/blocked.json" 2> "$root/blocked.err"; then
  echo 'FAIL: OpenAI live path succeeded without QUEUEBASH_AI_LIVE_ENABLED' >&2
  exit 1
fi
grep -q 'live_ai_provider_not_enabled' "$root/blocked.err"

# Helper itself fails closed before network when no key is configured.
cat > "$root/request.json" <<'JSON'
{"schema":"queuebash.ai_advisory.request.v1","operation":"ai.ask","provider":"openai","model":"gpt-4.1-mini","question":"hello","context_allowed":"docs","dynamic_context_text":"","advisory_only":true}
JSON
if bin/queue-ai-ask-openai --request-json "$root/request.json" --output-json "$root/response.json" >/dev/null 2> "$root/helper.err"; then
  echo 'FAIL: OpenAI helper succeeded without API key' >&2
  exit 1
fi
python3 - "$root/response.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ai_advisory.response.v1'
assert j['provider']=='openai'
assert j['status']=='error'
assert j['reason']=='openai_api_key_missing'
assert j['live_call_performed'] is False
assert j['advisory_only'] is True
PY

echo PASS
