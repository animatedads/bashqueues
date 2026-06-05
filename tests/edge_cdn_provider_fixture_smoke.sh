#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/edge_cdn/edge_cdn_provider.sh"
QUEUEBASH_EDGE_CDN_FIXTURE_DIR="$PWD/tests/fixtures/edge_cdn" bash "$helper" detect > /tmp/edge_cdn_detect.json
python3 -m json.tool /tmp/edge_cdn_detect.json >/dev/null
QUEUEBASH_EDGE_CDN_FIXTURE_DIR="$PWD/tests/fixtures/edge_cdn" bash "$helper" distribution explain > /tmp/edge_cdn_distribution.json
python3 -m json.tool /tmp/edge_cdn_distribution.json >/dev/null
QUEUEBASH_EDGE_CDN_FIXTURE_DIR="$PWD/tests/fixtures/edge_cdn" bash "$helper" origin explain > /tmp/edge_cdn_origin.json
python3 -m json.tool /tmp/edge_cdn_origin.json >/dev/null
QUEUEBASH_EDGE_CDN_FIXTURE_DIR="$PWD/tests/fixtures/edge_cdn" bash "$helper" cache explain > /tmp/edge_cdn_cache.json
python3 -m json.tool /tmp/edge_cdn_cache.json >/dev/null
QUEUEBASH_EDGE_CDN_FIXTURE_DIR="$PWD/tests/fixtures/edge_cdn" bash "$helper" policy explain > /tmp/edge_cdn_policy.json
python3 -m json.tool /tmp/edge_cdn_policy.json >/dev/null
printf 'PASS edge_cdn_provider_fixture_smoke
'
