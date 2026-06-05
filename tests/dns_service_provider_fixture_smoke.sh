#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/dns_service/dns_service_provider.sh"
QUEUEBASH_DNS_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/dns_service" bash "$helper" detect > /tmp/dns_service_detect.json
python3 -m json.tool /tmp/dns_service_detect.json >/dev/null
QUEUEBASH_DNS_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/dns_service" bash "$helper" zone explain > /tmp/dns_service_zone.json
python3 -m json.tool /tmp/dns_service_zone.json >/dev/null
QUEUEBASH_DNS_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/dns_service" bash "$helper" record explain > /tmp/dns_service_record.json
python3 -m json.tool /tmp/dns_service_record.json >/dev/null
QUEUEBASH_DNS_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/dns_service" bash "$helper" resolver explain > /tmp/dns_service_resolver.json
python3 -m json.tool /tmp/dns_service_resolver.json >/dev/null
QUEUEBASH_DNS_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/dns_service" bash "$helper" policy explain > /tmp/dns_service_policy.json
python3 -m json.tool /tmp/dns_service_policy.json >/dev/null
printf 'PASS dns_service_provider_fixture_smoke
'
