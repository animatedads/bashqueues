#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/search_service/search_service_provider.sh"
QUEUEBASH_SEARCH_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/search_service" bash "$helper" detect > /tmp/search_service_detect.json
python3 -m json.tool /tmp/search_service_detect.json >/dev/null
QUEUEBASH_SEARCH_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/search_service" bash "$helper" domain explain > /tmp/search_service_domain.json
python3 -m json.tool /tmp/search_service_domain.json >/dev/null
QUEUEBASH_SEARCH_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/search_service" bash "$helper" index explain > /tmp/search_service_index.json
python3 -m json.tool /tmp/search_service_index.json >/dev/null
QUEUEBASH_SEARCH_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/search_service" bash "$helper" policy explain > /tmp/search_service_policy.json
python3 -m json.tool /tmp/search_service_policy.json >/dev/null
QUEUEBASH_SEARCH_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/search_service" bash "$helper" query explain > /tmp/search_service_query.json
python3 -m json.tool /tmp/search_service_query.json >/dev/null
printf 'PASS search_service_provider_fixture_smoke
'
