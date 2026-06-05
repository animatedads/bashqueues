#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/secrets_scanner/secrets_scanner_provider.sh"
QUEUEBASH_SECRETS_SCANNER_FIXTURE_DIR="$PWD/tests/fixtures/secrets_scanner" bash "$helper" detect > /tmp/secrets_scanner_detect.json
python3 -m json.tool /tmp/secrets_scanner_detect.json >/dev/null
QUEUEBASH_SECRETS_SCANNER_FIXTURE_DIR="$PWD/tests/fixtures/secrets_scanner" bash "$helper" rule explain > /tmp/secrets_scanner_rule.json
python3 -m json.tool /tmp/secrets_scanner_rule.json >/dev/null
QUEUEBASH_SECRETS_SCANNER_FIXTURE_DIR="$PWD/tests/fixtures/secrets_scanner" bash "$helper" finding explain > /tmp/secrets_scanner_finding.json
python3 -m json.tool /tmp/secrets_scanner_finding.json >/dev/null
QUEUEBASH_SECRETS_SCANNER_FIXTURE_DIR="$PWD/tests/fixtures/secrets_scanner" bash "$helper" scope explain > /tmp/secrets_scanner_scope.json
python3 -m json.tool /tmp/secrets_scanner_scope.json >/dev/null
QUEUEBASH_SECRETS_SCANNER_FIXTURE_DIR="$PWD/tests/fixtures/secrets_scanner" bash "$helper" policy explain > /tmp/secrets_scanner_policy.json
python3 -m json.tool /tmp/secrets_scanner_policy.json >/dev/null
printf 'PASS secrets_scanner_provider_fixture_smoke
'
