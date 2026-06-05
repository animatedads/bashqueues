#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/configuration_database/configuration_database_provider.sh"
QUEUEBASH_CONFIGURATION_DATABASE_FIXTURE_DIR="$PWD/tests/fixtures/configuration_database" "$helper" detect > /tmp/configuration_database_detect.json
python3 -m json.tool /tmp/configuration_database_detect.json >/dev/null
QUEUEBASH_CONFIGURATION_DATABASE_FIXTURE_DIR="$PWD/tests/fixtures/configuration_database" "$helper" ci explain > /tmp/configuration_database_ci.json
python3 -m json.tool /tmp/configuration_database_ci.json >/dev/null
QUEUEBASH_CONFIGURATION_DATABASE_FIXTURE_DIR="$PWD/tests/fixtures/configuration_database" "$helper" relationship explain > /tmp/configuration_database_relationship.json
python3 -m json.tool /tmp/configuration_database_relationship.json >/dev/null
QUEUEBASH_CONFIGURATION_DATABASE_FIXTURE_DIR="$PWD/tests/fixtures/configuration_database" "$helper" change_window explain > /tmp/configuration_database_change_window.json
python3 -m json.tool /tmp/configuration_database_change_window.json >/dev/null
QUEUEBASH_CONFIGURATION_DATABASE_FIXTURE_DIR="$PWD/tests/fixtures/configuration_database" "$helper" policy explain > /tmp/configuration_database_policy.json
python3 -m json.tool /tmp/configuration_database_policy.json >/dev/null
printf 'PASS configuration_database_provider_fixture_smoke\n'
