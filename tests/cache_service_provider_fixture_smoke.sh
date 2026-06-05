#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/cache_service/cache_service_provider.sh"
QUEUEBASH_CACHE_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/cache_service" bash "$helper" detect > /tmp/cache_service_detect.json
python3 -m json.tool /tmp/cache_service_detect.json >/dev/null
QUEUEBASH_CACHE_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/cache_service" bash "$helper" cluster explain > /tmp/cache_service_cluster.json
python3 -m json.tool /tmp/cache_service_cluster.json >/dev/null
QUEUEBASH_CACHE_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/cache_service" bash "$helper" endpoint explain > /tmp/cache_service_endpoint.json
python3 -m json.tool /tmp/cache_service_endpoint.json >/dev/null
QUEUEBASH_CACHE_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/cache_service" bash "$helper" policy explain > /tmp/cache_service_policy.json
python3 -m json.tool /tmp/cache_service_policy.json >/dev/null
QUEUEBASH_CACHE_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/cache_service" bash "$helper" metrics explain > /tmp/cache_service_metrics.json
python3 -m json.tool /tmp/cache_service_metrics.json >/dev/null
printf 'PASS cache_service_provider_fixture_smoke
'
