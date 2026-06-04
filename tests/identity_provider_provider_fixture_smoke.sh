#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/identity_provider/identity_provider_provider.sh"
QUEUEBASH_IDENTITY_PROVIDER_FIXTURE_DIR="$PWD/tests/fixtures/identity_provider" "$helper" detect > /tmp/identity_provider_detect.json
python3 -m json.tool /tmp/identity_provider_detect.json >/dev/null
QUEUEBASH_IDENTITY_PROVIDER_FIXTURE_DIR="$PWD/tests/fixtures/identity_provider" "$helper" directory explain > /tmp/identity_provider_directory.json
python3 -m json.tool /tmp/identity_provider_directory.json >/dev/null
QUEUEBASH_IDENTITY_PROVIDER_FIXTURE_DIR="$PWD/tests/fixtures/identity_provider" "$helper" authentication explain > /tmp/identity_provider_authentication.json
python3 -m json.tool /tmp/identity_provider_authentication.json >/dev/null
QUEUEBASH_IDENTITY_PROVIDER_FIXTURE_DIR="$PWD/tests/fixtures/identity_provider" "$helper" federation explain > /tmp/identity_provider_federation.json
python3 -m json.tool /tmp/identity_provider_federation.json >/dev/null
QUEUEBASH_IDENTITY_PROVIDER_FIXTURE_DIR="$PWD/tests/fixtures/identity_provider" "$helper" group explain > /tmp/identity_provider_group.json
python3 -m json.tool /tmp/identity_provider_group.json >/dev/null
printf 'PASS identity_provider_provider_fixture_smoke
'
