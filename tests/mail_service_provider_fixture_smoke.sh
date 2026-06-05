#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/mail_service/mail_service_provider.sh"
QUEUEBASH_MAIL_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/mail_service" bash "$helper" detect > /tmp/mail_service_detect.json
python3 -m json.tool /tmp/mail_service_detect.json >/dev/null
QUEUEBASH_MAIL_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/mail_service" bash "$helper" domain explain > /tmp/mail_service_domain.json
python3 -m json.tool /tmp/mail_service_domain.json >/dev/null
QUEUEBASH_MAIL_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/mail_service" bash "$helper" sender explain > /tmp/mail_service_sender.json
python3 -m json.tool /tmp/mail_service_sender.json >/dev/null
QUEUEBASH_MAIL_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/mail_service" bash "$helper" delivery explain > /tmp/mail_service_delivery.json
python3 -m json.tool /tmp/mail_service_delivery.json >/dev/null
QUEUEBASH_MAIL_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/mail_service" bash "$helper" policy explain > /tmp/mail_service_policy.json
python3 -m json.tool /tmp/mail_service_policy.json >/dev/null
printf 'PASS mail_service_provider_fixture_smoke
'
