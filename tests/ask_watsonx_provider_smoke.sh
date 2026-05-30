#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$(mktemp -d "${TMPDIR:-/tmp}/queue-ask-watsonx-smoke.XXXXXX")"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root/qroot"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1

queue_ask_smoke_eval='source ./queuebash.sh; _queue_install_bundled_classes(){ :; }; _queue_install_bundled_env_profiles(){ :; }; _queue_install_bundled_asset_plugins(){ :; }; _queue_install_bundled_cap_plugins(){ :; }; _queue_install_bundled_reporter_plugins(){ :; }; _queue_install_bundled_policies(){ :; }; '

timeout 30 bash -lc "${queue_ask_smoke_eval} queue ask provider explain watsonx --json" > "$root/watsonx-discovery.json"
python3 - "$root/watsonx-discovery.json" <<'PYJSON1'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ask_provider.discovery.v1'
assert j['provider']=='watsonx'
assert j['requires_network'] is True
assert j['supports_json'] is True
assert j['live_supported'] is True
PYJSON1

timeout 30 bash -lc "${queue_ask_smoke_eval} queue ask provider test watsonx --fixture --json" > "$root/watsonx-fixture.json"
python3 - "$root/watsonx-fixture.json" <<'PYJSON2'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ask_provider.fixture_test.v1'
assert j['provider']=='watsonx'
assert j['status']=='ok'
assert j['live_call_performed'] is False
PYJSON2

if timeout 30 bash -lc "${queue_ask_smoke_eval} queue ask --provider watsonx --live --json 'What is queue ask?'" > "$root/blocked.json" 2> "$root/blocked.err"; then
  echo 'FAIL: watsonx live path succeeded without QUEUEBASH_AI_LIVE_ENABLED' >&2
  exit 1
fi
grep -q 'live_ai_provider_not_enabled' "$root/blocked.err"

cat > "$root/request.json" <<'JSONREQ'
{"schema":"queuebash.ai_advisory.request.v1","operation":"ai.ask","provider":"watsonx","model":"ibm/granite-3-8b-instruct","question":"hello","context_allowed":"docs","dynamic_context_text":"","advisory_only":true}
JSONREQ
if bin/queue-ai-ask-watsonx --request-json "$root/request.json" --output-json "$root/response.json" >/dev/null 2> "$root/helper.err"; then
  echo 'FAIL: watsonx helper succeeded without project id/credentials' >&2
  exit 1
fi
python3 - "$root/response.json" <<'PYJSON3'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ai_advisory.response.v1'
assert j['provider']=='watsonx'
assert j['status']=='error'
assert j['reason']=='watsonx_project_id_missing'
assert j['live_call_performed'] is False
assert j['advisory_only'] is True
PYJSON3

echo PASS
