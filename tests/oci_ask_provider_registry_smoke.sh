#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_AI_LIVE_ENABLED=1
source ./queuebash.sh

providers_json="$(queue ask providers --json)"
PROVIDERS_JSON="$providers_json" python3 - <<'PY'
import json,os
payload=json.loads(os.environ['PROVIDERS_JSON'])
providers={p.get('provider'):p for p in payload.get('providers',[])}
assert 'oci' in providers, providers.keys()
oci=providers['oci']
assert oci.get('live_supported') is True, oci
assert oci.get('requires_network') is True, oci
assert oci.get('policy',{}).get('allowed') is True, oci
PY

explain_json="$(queue ask provider explain oci --json)"
EXPLAIN_JSON="$explain_json" python3 - <<'PY'
import json,os
payload=json.loads(os.environ['EXPLAIN_JSON'])
assert payload.get('provider') == 'oci', payload
assert payload.get('live_supported') is True, payload
assert payload.get('requires_network') is True, payload
assert payload.get('policy',{}).get('allowed') is True, payload
PY

set +e
out="$(QUEUEBASH_AI_LIVE_ENABLED=0 queue ask --provider oci --live 'test oci provider policy' 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]]
[[ "$out" == *"live_ai_provider_not_enabled"* ]]

printf 'oci_ask_provider_registry_smoke: ok\n'
