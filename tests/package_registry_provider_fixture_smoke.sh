#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/package_registry/package_registry_provider.sh"
QUEUEBASH_PACKAGE_REGISTRY_FIXTURE_DIR="$PWD/tests/fixtures/package_registry" bash "$helper" detect > /tmp/package_registry_detect.json
python3 -m json.tool /tmp/package_registry_detect.json >/dev/null
QUEUEBASH_PACKAGE_REGISTRY_FIXTURE_DIR="$PWD/tests/fixtures/package_registry" bash "$helper" repository explain > /tmp/package_registry_repository.json
python3 -m json.tool /tmp/package_registry_repository.json >/dev/null
QUEUEBASH_PACKAGE_REGISTRY_FIXTURE_DIR="$PWD/tests/fixtures/package_registry" bash "$helper" package explain > /tmp/package_registry_package.json
python3 -m json.tool /tmp/package_registry_package.json >/dev/null
QUEUEBASH_PACKAGE_REGISTRY_FIXTURE_DIR="$PWD/tests/fixtures/package_registry" bash "$helper" provenance explain > /tmp/package_registry_provenance.json
python3 -m json.tool /tmp/package_registry_provenance.json >/dev/null
QUEUEBASH_PACKAGE_REGISTRY_FIXTURE_DIR="$PWD/tests/fixtures/package_registry" bash "$helper" policy explain > /tmp/package_registry_policy.json
python3 -m json.tool /tmp/package_registry_policy.json >/dev/null
printf 'PASS package_registry_provider_fixture_smoke
'
