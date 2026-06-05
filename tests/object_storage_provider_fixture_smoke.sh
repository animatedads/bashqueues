#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/object_storage/object_storage_provider.sh"
QUEUEBASH_OBJECT_STORAGE_FIXTURE_DIR="$PWD/tests/fixtures/object_storage" bash "$helper" detect > /tmp/object_storage_detect.json
python3 -m json.tool /tmp/object_storage_detect.json >/dev/null
QUEUEBASH_OBJECT_STORAGE_FIXTURE_DIR="$PWD/tests/fixtures/object_storage" bash "$helper" bucket explain > /tmp/object_storage_bucket.json
python3 -m json.tool /tmp/object_storage_bucket.json >/dev/null
QUEUEBASH_OBJECT_STORAGE_FIXTURE_DIR="$PWD/tests/fixtures/object_storage" bash "$helper" object explain > /tmp/object_storage_object.json
python3 -m json.tool /tmp/object_storage_object.json >/dev/null
QUEUEBASH_OBJECT_STORAGE_FIXTURE_DIR="$PWD/tests/fixtures/object_storage" bash "$helper" retention explain > /tmp/object_storage_retention.json
python3 -m json.tool /tmp/object_storage_retention.json >/dev/null
QUEUEBASH_OBJECT_STORAGE_FIXTURE_DIR="$PWD/tests/fixtures/object_storage" bash "$helper" policy explain > /tmp/object_storage_policy.json
python3 -m json.tool /tmp/object_storage_policy.json >/dev/null
printf 'PASS object_storage_provider_fixture_smoke
'
