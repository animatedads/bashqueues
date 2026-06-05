#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/backup_service/backup_service_provider.sh"
QUEUEBASH_BACKUP_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/backup_service" "$helper" detect > /tmp/backup_service_detect.json
python3 -m json.tool /tmp/backup_service_detect.json >/dev/null
QUEUEBASH_BACKUP_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/backup_service" "$helper" policy explain > /tmp/backup_service_policy.json
python3 -m json.tool /tmp/backup_service_policy.json >/dev/null
QUEUEBASH_BACKUP_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/backup_service" "$helper" repository explain > /tmp/backup_service_repository.json
python3 -m json.tool /tmp/backup_service_repository.json >/dev/null
QUEUEBASH_BACKUP_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/backup_service" "$helper" schedule explain > /tmp/backup_service_schedule.json
python3 -m json.tool /tmp/backup_service_schedule.json >/dev/null
QUEUEBASH_BACKUP_SERVICE_FIXTURE_DIR="$PWD/tests/fixtures/backup_service" "$helper" recovery_point explain > /tmp/backup_service_recovery_point.json
python3 -m json.tool /tmp/backup_service_recovery_point.json >/dev/null
printf 'PASS backup_service_provider_fixture_smoke
'
