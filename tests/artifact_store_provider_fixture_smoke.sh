#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/artifact_store/artifact_store_provider.sh"
QUEUEBASH_ARTIFACT_STORE_FIXTURE_DIR="$PWD/tests/fixtures/artifact_store" "$helper" detect > /tmp/artifact_store_detect.json
python3 -m json.tool /tmp/artifact_store_detect.json >/dev/null
QUEUEBASH_ARTIFACT_STORE_FIXTURE_DIR="$PWD/tests/fixtures/artifact_store" "$helper" artifact explain > /tmp/artifact_store_artifact.json
python3 -m json.tool /tmp/artifact_store_artifact.json >/dev/null
QUEUEBASH_ARTIFACT_STORE_FIXTURE_DIR="$PWD/tests/fixtures/artifact_store" "$helper" provenance explain > /tmp/artifact_store_provenance.json
python3 -m json.tool /tmp/artifact_store_provenance.json >/dev/null
QUEUEBASH_ARTIFACT_STORE_FIXTURE_DIR="$PWD/tests/fixtures/artifact_store" "$helper" retention explain > /tmp/artifact_store_retention.json
python3 -m json.tool /tmp/artifact_store_retention.json >/dev/null
QUEUEBASH_ARTIFACT_STORE_FIXTURE_DIR="$PWD/tests/fixtures/artifact_store" "$helper" integrity explain > /tmp/artifact_store_integrity.json
python3 -m json.tool /tmp/artifact_store_integrity.json >/dev/null
printf 'PASS artifact_store_provider_fixture_smoke
'
