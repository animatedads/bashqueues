#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/load_balancer/load_balancer_provider.sh"
QUEUEBASH_LOAD_BALANCER_FIXTURE_DIR="$PWD/tests/fixtures/load_balancer" bash "$helper" detect > /tmp/load_balancer_detect.json
python3 -m json.tool /tmp/load_balancer_detect.json >/dev/null
QUEUEBASH_LOAD_BALANCER_FIXTURE_DIR="$PWD/tests/fixtures/load_balancer" bash "$helper" balancer explain > /tmp/load_balancer_balancer.json
python3 -m json.tool /tmp/load_balancer_balancer.json >/dev/null
QUEUEBASH_LOAD_BALANCER_FIXTURE_DIR="$PWD/tests/fixtures/load_balancer" bash "$helper" listener explain > /tmp/load_balancer_listener.json
python3 -m json.tool /tmp/load_balancer_listener.json >/dev/null
QUEUEBASH_LOAD_BALANCER_FIXTURE_DIR="$PWD/tests/fixtures/load_balancer" bash "$helper" target explain > /tmp/load_balancer_target.json
python3 -m json.tool /tmp/load_balancer_target.json >/dev/null
QUEUEBASH_LOAD_BALANCER_FIXTURE_DIR="$PWD/tests/fixtures/load_balancer" bash "$helper" health explain > /tmp/load_balancer_health.json
python3 -m json.tool /tmp/load_balancer_health.json >/dev/null
printf 'PASS load_balancer_provider_fixture_smoke
'
