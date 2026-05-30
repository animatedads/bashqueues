#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$(mktemp -d "${TMPDIR:-/tmp}/queue-ask-provider-smoke.XXXXXX")"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root/qroot"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1

queue_ask_smoke_eval='source ./queuebash.sh; _queue_install_bundled_classes(){ :; }; _queue_install_bundled_env_profiles(){ :; }; _queue_install_bundled_asset_plugins(){ :; }; _queue_install_bundled_cap_plugins(){ :; }; _queue_install_bundled_reporter_plugins(){ :; }; _queue_install_bundled_policies(){ :; }; '


timeout 30 bash -lc "${queue_ask_smoke_eval} queue ask providers --json" > "$root/providers.json"
python3 - "$root/providers.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ask_provider.list.v1'
providers=[p['provider'] for p in j['providers']]
assert 'fixture' in providers
assert 'contract' in providers
PY

timeout 30 bash -lc "${queue_ask_smoke_eval} queue ask provider explain fixture --json" > "$root/fixture.json"
python3 - "$root/fixture.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ask_provider.discovery.v1'
assert j['provider']=='fixture'
assert j['requires_network'] is False
assert j['supports_fixture'] is True
PY

timeout 30 bash -lc "${queue_ask_smoke_eval} queue ask provider test fixture --fixture --json" > "$root/test.json"
python3 - "$root/test.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ask_provider.fixture_test.v1'
assert j['status']=='ok'
assert j['live_call_performed'] is False
PY

timeout 30 bash -lc "${queue_ask_smoke_eval} queue ask --provider fixture --json 'How do I inspect queue ask providers?'" > "$root/ask.json"
python3 -c 'import json,sys; j=json.load(open(sys.argv[1])); assert j["schema"]=="queuebash.ask_provider.response.v1"; assert j["provider"]=="fixture"; assert j["status"]=="ok"; assert j["live_call_performed"] is False; assert j["advisory_only"] is True; assert "Fixture ask provider response" in j["answer_markdown"]' "$root/ask.json"

echo PASS
