#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/key_value_store/key_value_store_provider.sh"
QUEUEBASH_KEY_VALUE_STORE_FIXTURE_DIR="$PWD/tests/fixtures/key_value_store" bash "$helper" detect > /tmp/key_value_store_detect.json
python3 -m json.tool /tmp/key_value_store_detect.json >/dev/null
QUEUEBASH_KEY_VALUE_STORE_FIXTURE_DIR="$PWD/tests/fixtures/key_value_store" bash "$helper" table explain > /tmp/key_value_store_table.json
python3 -m json.tool /tmp/key_value_store_table.json >/dev/null
QUEUEBASH_KEY_VALUE_STORE_FIXTURE_DIR="$PWD/tests/fixtures/key_value_store" bash "$helper" capacity explain > /tmp/key_value_store_capacity.json
python3 -m json.tool /tmp/key_value_store_capacity.json >/dev/null
QUEUEBASH_KEY_VALUE_STORE_FIXTURE_DIR="$PWD/tests/fixtures/key_value_store" bash "$helper" policy explain > /tmp/key_value_store_policy.json
python3 -m json.tool /tmp/key_value_store_policy.json >/dev/null
QUEUEBASH_KEY_VALUE_STORE_FIXTURE_DIR="$PWD/tests/fixtures/key_value_store" bash "$helper" backup explain > /tmp/key_value_store_backup.json
python3 -m json.tool /tmp/key_value_store_backup.json >/dev/null
printf 'PASS key_value_store_provider_fixture_smoke
'
