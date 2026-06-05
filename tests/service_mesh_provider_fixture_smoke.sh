#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/service_mesh/service_mesh_provider.sh"
QUEUEBASH_SERVICE_MESH_FIXTURE_DIR="$PWD/tests/fixtures/service_mesh" bash "$helper" detect > /tmp/service_mesh_detect.json
python3 -m json.tool /tmp/service_mesh_detect.json >/dev/null
QUEUEBASH_SERVICE_MESH_FIXTURE_DIR="$PWD/tests/fixtures/service_mesh" bash "$helper" mesh explain > /tmp/service_mesh_mesh.json
python3 -m json.tool /tmp/service_mesh_mesh.json >/dev/null
QUEUEBASH_SERVICE_MESH_FIXTURE_DIR="$PWD/tests/fixtures/service_mesh" bash "$helper" route explain > /tmp/service_mesh_route.json
python3 -m json.tool /tmp/service_mesh_route.json >/dev/null
QUEUEBASH_SERVICE_MESH_FIXTURE_DIR="$PWD/tests/fixtures/service_mesh" bash "$helper" identity explain > /tmp/service_mesh_identity.json
python3 -m json.tool /tmp/service_mesh_identity.json >/dev/null
QUEUEBASH_SERVICE_MESH_FIXTURE_DIR="$PWD/tests/fixtures/service_mesh" bash "$helper" policy explain > /tmp/service_mesh_policy.json
python3 -m json.tool /tmp/service_mesh_policy.json >/dev/null
printf 'PASS service_mesh_provider_fixture_smoke
'
