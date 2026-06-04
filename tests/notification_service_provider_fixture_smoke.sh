#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/notification_service/notification_service_provider.sh"
QUEUEBASH_NOTIFICATION_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/notification_service" "$helper" detect > /tmp/notification_service_detect.json
python3 -m json.tool /tmp/notification_service_detect.json >/dev/null
QUEUEBASH_NOTIFICATION_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/notification_service" "$helper" channel explain > /tmp/notification_service_channel.json
python3 -m json.tool /tmp/notification_service_channel.json >/dev/null
QUEUEBASH_NOTIFICATION_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/notification_service" "$helper" route explain > /tmp/notification_service_route.json
python3 -m json.tool /tmp/notification_service_route.json >/dev/null
QUEUEBASH_NOTIFICATION_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/notification_service" "$helper" template explain > /tmp/notification_service_template.json
python3 -m json.tool /tmp/notification_service_template.json >/dev/null
QUEUEBASH_NOTIFICATION_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/notification_service" "$helper" delivery explain > /tmp/notification_service_delivery.json
python3 -m json.tool /tmp/notification_service_delivery.json >/dev/null
printf 'PASS notification_service_provider_fixture_smoke
'
