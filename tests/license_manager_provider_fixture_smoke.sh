#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/license_manager/license_manager_provider.sh"
QUEUEBASH_LICENSE_MANAGER_FIXTURE_DIR="$PWD/tests/fixtures/license_manager" "$helper" detect > /tmp/license_manager_detect.json
python3 -m json.tool /tmp/license_manager_detect.json >/dev/null
QUEUEBASH_LICENSE_MANAGER_FIXTURE_DIR="$PWD/tests/fixtures/license_manager" "$helper" entitlement explain > /tmp/license_manager_entitlement.json
python3 -m json.tool /tmp/license_manager_entitlement.json >/dev/null
QUEUEBASH_LICENSE_MANAGER_FIXTURE_DIR="$PWD/tests/fixtures/license_manager" "$helper" pool explain > /tmp/license_manager_pool.json
python3 -m json.tool /tmp/license_manager_pool.json >/dev/null
QUEUEBASH_LICENSE_MANAGER_FIXTURE_DIR="$PWD/tests/fixtures/license_manager" "$helper" usage explain > /tmp/license_manager_usage.json
python3 -m json.tool /tmp/license_manager_usage.json >/dev/null
QUEUEBASH_LICENSE_MANAGER_FIXTURE_DIR="$PWD/tests/fixtures/license_manager" "$helper" policy explain > /tmp/license_manager_policy.json
python3 -m json.tool /tmp/license_manager_policy.json >/dev/null
printf 'PASS license_manager_provider_fixture_smoke\n'
