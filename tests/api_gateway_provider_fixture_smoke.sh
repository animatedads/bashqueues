#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/api_gateway/api_gateway_provider.sh"
QUEUEBASH_API_GATEWAY_FIXTURE_DIR="$PWD/tests/fixtures/api_gateway" bash "$helper" detect > /tmp/api_gateway_detect.json
python3 -m json.tool /tmp/api_gateway_detect.json >/dev/null
QUEUEBASH_API_GATEWAY_FIXTURE_DIR="$PWD/tests/fixtures/api_gateway" bash "$helper" gateway explain > /tmp/api_gateway_gateway.json
python3 -m json.tool /tmp/api_gateway_gateway.json >/dev/null
QUEUEBASH_API_GATEWAY_FIXTURE_DIR="$PWD/tests/fixtures/api_gateway" bash "$helper" route explain > /tmp/api_gateway_route.json
python3 -m json.tool /tmp/api_gateway_route.json >/dev/null
QUEUEBASH_API_GATEWAY_FIXTURE_DIR="$PWD/tests/fixtures/api_gateway" bash "$helper" auth explain > /tmp/api_gateway_auth.json
python3 -m json.tool /tmp/api_gateway_auth.json >/dev/null
QUEUEBASH_API_GATEWAY_FIXTURE_DIR="$PWD/tests/fixtures/api_gateway" bash "$helper" policy explain > /tmp/api_gateway_policy.json
python3 -m json.tool /tmp/api_gateway_policy.json >/dev/null
printf 'PASS api_gateway_provider_fixture_smoke
'
