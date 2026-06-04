#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/metadata_catalog/metadata_catalog_provider.sh"
QUEUEBASH_METADATA_CATALOG_FIXTURE_DIR="$PWD/tests/fixtures/metadata_catalog" "$helper" detect > /tmp/metadata_catalog_detect.json
python3 -m json.tool /tmp/metadata_catalog_detect.json >/dev/null
QUEUEBASH_METADATA_CATALOG_FIXTURE_DIR="$PWD/tests/fixtures/metadata_catalog" "$helper" catalog explain > /tmp/metadata_catalog_catalog.json
python3 -m json.tool /tmp/metadata_catalog_catalog.json >/dev/null
QUEUEBASH_METADATA_CATALOG_FIXTURE_DIR="$PWD/tests/fixtures/metadata_catalog" "$helper" asset explain > /tmp/metadata_catalog_asset.json
python3 -m json.tool /tmp/metadata_catalog_asset.json >/dev/null
QUEUEBASH_METADATA_CATALOG_FIXTURE_DIR="$PWD/tests/fixtures/metadata_catalog" "$helper" lineage explain > /tmp/metadata_catalog_lineage.json
python3 -m json.tool /tmp/metadata_catalog_lineage.json >/dev/null
QUEUEBASH_METADATA_CATALOG_FIXTURE_DIR="$PWD/tests/fixtures/metadata_catalog" "$helper" classification explain > /tmp/metadata_catalog_classification.json
python3 -m json.tool /tmp/metadata_catalog_classification.json >/dev/null
printf 'PASS metadata_catalog_provider_fixture_smoke
'
