#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/schema_registry/schema_registry_provider.sh"
QUEUEBASH_SCHEMA_REGISTRY_FIXTURE_DIR="$PWD/tests/fixtures/schema_registry" "$helper" detect > /tmp/schema_registry_detect.json
python3 -m json.tool /tmp/schema_registry_detect.json >/dev/null
QUEUEBASH_SCHEMA_REGISTRY_FIXTURE_DIR="$PWD/tests/fixtures/schema_registry" "$helper" registry explain > /tmp/schema_registry_registry.json
python3 -m json.tool /tmp/schema_registry_registry.json >/dev/null
QUEUEBASH_SCHEMA_REGISTRY_FIXTURE_DIR="$PWD/tests/fixtures/schema_registry" "$helper" schema explain > /tmp/schema_registry_schema.json
python3 -m json.tool /tmp/schema_registry_schema.json >/dev/null
QUEUEBASH_SCHEMA_REGISTRY_FIXTURE_DIR="$PWD/tests/fixtures/schema_registry" "$helper" compatibility explain > /tmp/schema_registry_compatibility.json
python3 -m json.tool /tmp/schema_registry_compatibility.json >/dev/null
QUEUEBASH_SCHEMA_REGISTRY_FIXTURE_DIR="$PWD/tests/fixtures/schema_registry" "$helper" governance explain > /tmp/schema_registry_governance.json
python3 -m json.tool /tmp/schema_registry_governance.json >/dev/null
printf 'PASS schema_registry_provider_fixture_smoke
'
